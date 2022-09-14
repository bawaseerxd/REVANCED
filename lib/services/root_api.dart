import 'package:root/root.dart';

class RootAPI {
  final String _managerDirPath = '/data/adb/revanced-manager';
  final String _managerTmpDirPath = '/data/local/tmp/revanced-manager';
  final String _postFsDataDirPath = '/data/adb/post-fs-data.d';
  final String _serviceDDirPath = '/data/adb/service.d';

  Future<bool> hasRootPermissions() async {
    bool? isRooted = await Root.isRooted();
    return isRooted != null && isRooted;
  }

  Future<void> setPermissions(
    String permissions,
    ownerGroup,
    seLinux,
    String filePath,
  ) async {
    if (permissions.isNotEmpty) {
      await Root.exec(
        cmd: 'chmod $permissions "$filePath"',
      );
    }
    if (ownerGroup.isNotEmpty) {
      await Root.exec(
        cmd: 'chown $ownerGroup "$filePath"',
      );
    }
    if (seLinux.isNotEmpty) {
      await Root.exec(
        cmd: 'chcon $seLinux "$filePath"',
      );
    }
  }

  Future<bool> isAppInstalled(String packageName) async {
    if (packageName.isNotEmpty) {
      String? res = await Root.exec(
        cmd: 'ls "$_managerDirPath/$packageName"',
      );
      if (res != null && res.isNotEmpty) {
        res = await Root.exec(
          cmd: 'ls "$_serviceDDirPath/$packageName.sh"',
        );
        return res != null && res.isNotEmpty;
      }
    }
    return false;
  }

  Future<List<String>> getInstalledApps() async {
    try {
      String? res = await Root.exec(
        cmd: 'ls "$_managerDirPath"',
      );
      if (res != null) {
        List<String> apps = res.split('\n');
        List<String> toRemove = [];
        for (String packageName in apps) {
          bool isInstalled = await isAppInstalled(packageName);
          if (!isInstalled) {
            toRemove.add(packageName);
          }
        }
        apps.removeWhere((a) => toRemove.contains(a));
        return apps;
      }
    } on Exception {
      return List.empty();
    }
    return List.empty();
  }

  Future<void> deleteApp(String packageName, String originalFilePath) async {
    await Root.exec(
      cmd: 'am force-stop "$packageName"',
    );
    await Root.exec(
      cmd: 'su -mm -c "umount -l $originalFilePath"',
    );
    await Root.exec(
      cmd: 'rm -rf "$_managerDirPath/$packageName"',
    );
    await Root.exec(
      cmd: 'rm -rf "$_serviceDDirPath/$packageName.sh"',
    );
    await Root.exec(
      cmd: 'rm -rf "$_postFsDataDirPath/$packageName.sh"',
    );
  }

  Future<bool> installApp(
    String packageName,
    String originalFilePath,
    String patchedFilePath,
  ) async {
    try {
      await deleteApp(packageName, originalFilePath);
      await Root.exec(
        cmd: 'mkdir -p "$_managerDirPath/$packageName"',
      );
      await setPermissions('0755', '', '', "$_managerDirPath/$packageName");
      await saveOriginalFilePath(packageName, originalFilePath);
      await installServiceDScript(packageName);
      await installPostFsDataScript(packageName);
      await installApk(packageName, patchedFilePath);
      await mountApk(packageName, originalFilePath);
      return true;
    } on Exception {
      return false;
    }
  }

  Future<void> installServiceDScript(String packageName) async {
    String content = '#!/system/bin/sh\n'
        'while [ "\$(getprop sys.boot_completed | tr -d \'"\'"\'\\\\r\'"\'"\')" != "1" ]; do sleep 1; done\n'
        'base_path=$_managerDirPath/$packageName/base.apk\n'
        'stock_path=\$(pm path $packageName | grep base | sed \'"\'"\'s/package://g\'"\'"\')\n'
        '[ ! -z \$stock_path ] && mount -o bind \$base_path \$stock_path';
    String scriptFilePath = '$_serviceDDirPath/$packageName.sh';
    await Root.exec(
      cmd: 'echo \'$content\' > "$scriptFilePath"',
    );
    await setPermissions('0744', '', '', scriptFilePath);
  }

  Future<void> installPostFsDataScript(String packageName) async {
    String content = '#!/system/bin/sh\n'
        'stock_path=\$(pm path $packageName | grep base | sed \'"\'"\'s/package://g\'"\'"\')\n'
        '[ ! -z \$stock_path ] && umount -l \$stock_path';
    String scriptFilePath = '$_postFsDataDirPath/$packageName.sh';
    await Root.exec(
      cmd: 'echo \'$content\' > "$scriptFilePath"',
    );
    await setPermissions('0744', '', '', scriptFilePath);
  }

  Future<void> installApk(String packageName, String patchedFilePath) async {
    String newPatchedFilePath = '$_managerDirPath/$packageName/base.apk';
    await Root.exec(
      cmd: 'cp "$patchedFilePath" "$newPatchedFilePath"',
    );
    await setPermissions(
      '0644',
      'system:system',
      'u:object_r:apk_data_file:s0',
      newPatchedFilePath,
    );
  }

  Future<void> mountApk(String packageName, String originalFilePath) async {
    String newPatchedFilePath = '$_managerDirPath/$packageName/base.apk';
    await Root.exec(
      cmd: 'am force-stop "$packageName"',
    );
    await Root.exec(
      cmd: 'su -mm -c "umount -l $originalFilePath"',
    );
    await Root.exec(
      cmd: 'su -mm -c "mount -o bind $newPatchedFilePath $originalFilePath"',
    );
  }

  Future<bool> isMounted(String packageName) async {
    String? res = await Root.exec(
      cmd: 'cat /proc/mounts | grep $packageName',
    );
    return res != null && res.isNotEmpty;
  }

  Future<String> getOriginalFilePath(
    String packageName,
    String originalFilePath,
  ) async {
    bool isInstalled = await isAppInstalled(packageName);
    if (isInstalled && await isMounted(packageName)) {
      originalFilePath = '$_managerTmpDirPath/$packageName/original.apk';
      await setPermissions(
        '0644',
        'shell:shell',
        'u:object_r:apk_data_file:s0',
        originalFilePath,
      );
    }
    return originalFilePath;
  }

  Future<void> saveOriginalFilePath(
    String packageName,
    String originalFilePath,
  ) async {
    String originalRootPath = '$_managerTmpDirPath/$packageName/original.apk';
    await Root.exec(
      cmd: 'mkdir -p "$_managerTmpDirPath/$packageName"',
    );
    await setPermissions(
      '0755',
      'shell:shell',
      '',
      '$_managerTmpDirPath/$packageName',
    );
    await Root.exec(
      cmd: 'cp "$originalFilePath" "$originalRootPath"',
    );
    await setPermissions(
      '0644',
      'shell:shell',
      'u:object_r:apk_data_file:s0',
      originalFilePath,
    );
  }
}
