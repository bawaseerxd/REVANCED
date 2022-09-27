import 'dart:io';
import 'package:app_installer/app_installer.dart';
import 'package:collection/collection.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:revanced_manager/app/app.locator.dart';
import 'package:revanced_manager/models/patch.dart';
import 'package:revanced_manager/models/patched_application.dart';
import 'package:revanced_manager/services/manager_api.dart';
import 'package:revanced_manager/services/root_api.dart';
import 'package:share_extend/share_extend.dart';

@lazySingleton
class PatcherAPI {
  static const patcherChannel =
      MethodChannel('app.revanced.manager.flutter/patcher');
  final ManagerAPI _managerAPI = locator<ManagerAPI>();
  final RootAPI _rootAPI = RootAPI();
  late Directory _tmpDir;
  late Directory _cacheDir;
  late Directory _workDir;
  late File _keyStoreFile;
  File? _jarPatchBundleFile;
  File? integrations;
  File? _inputFile;
  File? _patchedFile;
  File? _outFile;

  Future<void> initialize() async {
    Directory appCache = await getTemporaryDirectory();
    _tmpDir = Directory('${appCache.path}/patcher');
    _tmpDir.createSync();
    _workDir = _tmpDir.createTempSync("tmp-");
    _cacheDir = Directory('${_workDir.path}/cache');
    _keyStoreFile = File('${appCache.path}/revanced-manager.keystore');
    _cacheDir.createSync();
    cleanPatcher();
  }

  void cleanPatcher() {
    if (_tmpDir.existsSync()) {
      _tmpDir.deleteSync(recursive: true);
    }
  }

  Future<bool> loadPatches() async {
    try {
      if (_tmpDir == null) {
        await initialize();
      }

      if (_jarPatchBundleFile == null) {
        _jarPatchBundleFile = await _managerAPI.downloadPatches();
        if (_jarPatchBundleFile == null) {
          try {
            await patcherChannel.invokeMethod<bool>(
              'loadPatches',
              {
                'jarPatchBundlePath': _jarPatchBundleFile?.path,
                'cacheDirPath': _cacheDir.path,
              },
            );
          } on Exception {
            return false;
          }
        }
      }
    } on Exception {
      return false;
    }
    return _jarPatchBundleFile != null;
  }

  Future<List<ApplicationWithIcon>> getFilteredInstalledApps() async {
    List<ApplicationWithIcon> filteredApps = [];
    bool isLoaded = await loadPatches();
    if (isLoaded) {
      try {
        List<String>? patchesPackage = await patcherChannel
            .invokeListMethod<String>('getCompatiblePackages');
        if (patchesPackage != null) {
          for (String package in patchesPackage) {
            try {
              ApplicationWithIcon? app = await DeviceApps.getApp(package, true)
                  as ApplicationWithIcon?;
              if (app != null) {
                filteredApps.add(app);
              }
            } catch (e) {
              print(e);
              continue;
            }
          }
        }
      } on Exception {
        return List.empty();
      }
    }
    return filteredApps;
  }

  Future<List<Patch>> getFilteredPatches(
      PatchedApplication? selectedApp) async {
    List<Patch> filteredPatches = [];
    if (selectedApp != null) {
      bool isLoaded = await loadPatches();
      if (isLoaded) {
        try {
          var patches =
              await patcherChannel.invokeListMethod<Map<dynamic, dynamic>>(
            'getFilteredPatches',
            {
              'targetPackage': selectedApp.packageName,
              'targetVersion': selectedApp.version,
              'ignoreVersion': true,
            },
          );
          if (patches != null) {
            for (var patch in patches) {
              if (!filteredPatches
                  .any((element) => element.name == patch['name'])) {
                filteredPatches.add(
                  Patch(
                    name: patch['name'],
                    version: patch['version'],
                    description: patch['description'],
                    compatiblePackages: patch['compatiblePackages'],
                    dependencies: patch['dependencies'],
                    excluded: patch['excluded'],
                  ),
                );
              }
            }
          }
        } on Exception {
          return List.empty();
        }
      }
    }
    return filteredPatches;
  }

  Future<List<Patch>> getAppliedPatches(PatchedApplication? selectedApp) async {
    List<Patch> appliedPatches = [];
    if (selectedApp != null) {
      bool isLoaded = await loadPatches();
      if (isLoaded) {
        try {
          var patches =
              await patcherChannel.invokeListMethod<Map<dynamic, dynamic>>(
            'getFilteredPatches',
            {
              'targetPackage': selectedApp.packageName,
              'targetVersion': selectedApp.version,
              'ignoreVersion': true,
            },
          );
          if (patches != null) {
            for (var patch in patches) {
              if (selectedApp.appliedPatches.contains(patch['name'])) {
                appliedPatches.add(
                  Patch(
                    name: patch['name'],
                    version: patch['version'],
                    description: patch['description'],
                    compatiblePackages: patch['compatiblePackages'],
                    dependencies: patch['dependencies'],
                    excluded: patch['excluded'],
                  ),
                );
              }
            }
          }
        } on Exception {
          return List.empty();
        }
      }
    }
    return appliedPatches;
  }

  bool dependencyNeedsIntegrations(String name, List<Patch> selectedPatches) {
    return name.contains('integrations') ||
        selectedPatches.any(
          (patch) =>
              patch.name == name &&
              (patch.dependencies.any(
                (dep) => dependencyNeedsIntegrations(dep, selectedPatches),
              )),
        );
  }

  Future<bool> needsIntegrations(List<Patch> selectedPatches) async {
    return selectedPatches.any(
      (patch) => patch.dependencies.any(
        (dep) => dependencyNeedsIntegrations(dep, selectedPatches),
      ),
    );
  }

  Future<bool> needsResourcePatching(List<Patch> selectedPatches) async {
    return selectedPatches.any(
      (patch) => patch.dependencies.any(
        (dep) => dep.contains('resource-'),
      ),
    );
  }

  Future<bool> needsSettingsPatch(List<Patch> selectedPatches) async {
    return selectedPatches.any(
      (patch) => patch.dependencies.any(
        (dep) => dep.contains('settings'),
      ),
    );
  }

  Future<String> getOriginalFilePath(
    String packageName,
    String originalFilePath,
  ) async {
    bool hasRootPermissions = await _rootAPI.hasRootPermissions();
    if (hasRootPermissions) {
      originalFilePath = await _rootAPI.getOriginalFilePath(
        packageName,
        originalFilePath,
      );
    }
    return originalFilePath;
  }

  Future<void> runPatcher(
    String packageName,
    String originalFilePath,
    List<Patch> selectedPatches,
  ) async {
    bool mergeIntegrations = await needsIntegrations(selectedPatches);
    bool resourcePatching = await needsResourcePatching(selectedPatches);
    bool includeSettings = await needsSettingsPatch(selectedPatches);
    if (includeSettings) {
      try {
        Patch? settingsPatch = selectedPatches.firstWhereOrNull(
          (patch) =>
              patch.name.contains('settings') &&
              patch.compatiblePackages.any((pack) => pack.name == packageName),
        );
        if (settingsPatch != null) {
          selectedPatches.add(settingsPatch);
        }
      } catch (e) {
        // ignore
      }
    }
    File? patchBundleFile = await _managerAPI.downloadPatches();
    File? integrationsFile;
    if (mergeIntegrations) {
      integrationsFile = await _managerAPI.downloadIntegrations();
    }
    if (patchBundleFile != null) {
      _tmpDir.createSync();
      Directory workDir = _tmpDir.createTempSync('tmp-');
      File inputFile = File('${workDir.path}/base.apk');
      File patchedFile = File('${workDir.path}/patched.apk');
      _outFile = File('${workDir.path}/out.apk');
      Directory cacheDir = Directory('${workDir.path}/cache');
      cacheDir.createSync();
      await patcherChannel.invokeMethod(
        'runPatcher',
        {
          'patchBundleFilePath': patchBundleFile.path,
          'originalFilePath': await getOriginalFilePath(
            packageName,
            originalFilePath,
          ),
          'inputFilePath': inputFile.path,
          'patchedFilePath': patchedFile.path,
          'outFilePath': _outFile!.path,
          'integrationsPath': mergeIntegrations ? integrationsFile!.path : '',
          'selectedPatches': selectedPatches.map((p) => p.name).toList(),
          'cacheDirPath': cacheDir.path,
          'mergeIntegrations': mergeIntegrations,
          'resourcePatching': resourcePatching,
          'keyStoreFilePath': _keyStoreFile.path,
        },
      );
    }
  }

  Future<bool> installPatchedFile(PatchedApplication patchedApp) async {
    if (_outFile != null) {
      try {
        if (patchedApp.isRooted) {
          bool hasRootPermissions = await _rootAPI.hasRootPermissions();
          if (hasRootPermissions) {
            return _rootAPI.installApp(
              patchedApp.packageName,
              patchedApp.apkFilePath,
              _outFile!.path,
            );
          }
        } else {
          await AppInstaller.installApk(_outFile!.path);
          return await DeviceApps.isAppInstalled(patchedApp.packageName);
        }
      } on Exception {
        return false;
      }
    }
    return false;
  }

  void sharePatchedFile(String appName, String version) {
    if (_outFile != null) {
      String prefix = appName.toLowerCase().replaceAll(' ', '-');
      String newName = '$prefix-revanced_v$version.apk';
      int lastSeparator = _outFile!.path.lastIndexOf('/');
      String newPath = _outFile!.path.substring(0, lastSeparator + 1) + newName;
      File shareFile = _outFile!.copySync(newPath);
      ShareExtend.share(shareFile.path, 'file');
    }
  }

  Future<void> sharePatcherLog(String logs) async {
    Directory appCache = await getTemporaryDirectory();
    Directory logDir = Directory('${appCache.path}/logs');
    logDir.createSync();
    String dateTime = DateTime.now()
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .replaceAll('T', '')
        .replaceAll('.', '');
    File log = File('${logDir.path}/revanced-manager_patcher_$dateTime.log');
    log.writeAsStringSync(logs);
    ShareExtend.share(log.path, 'file');
  }

  Future<String> getRecommendedVersion(PatchedApplication? selectedApp) async {
    Map<String, int> versions = {};
    final patches = await getAppliedPatches(selectedApp);
    for (Patch patch in patches) {
      Package? package = patch.compatiblePackages.firstWhereOrNull(
        (pack) => pack.name == selectedApp!.packageName,
      );
      if (package != null) {
        for (String version in package.versions) {
          versions.update(
            version,
            (value) => versions[version]! + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }
    if (versions.isNotEmpty) {
      var entries = versions.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      versions
        ..clear()
        ..addEntries(entries);
      versions.removeWhere((key, value) => value != versions.values.last);
      return (versions.keys.toList()..sort()).last;
    }
    return '';
  }
}
