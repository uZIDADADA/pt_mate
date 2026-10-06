import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/fork_update_service.dart';

class ForkUpdateDialog extends StatefulWidget {
  const ForkUpdateDialog({super.key, required this.release});
  final ForkRelease release;

  @override
  State<ForkUpdateDialog> createState() => _ForkUpdateDialogState();
}

class _ForkUpdateDialogState extends State<ForkUpdateDialog> {
  CancelToken? _cancel;
  double? _progress;
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _message = null;
      _progress = 0;
    });
    _cancel = CancelToken();
    try {
      final launched = await ForkUpdateService.instance.downloadAndInstall(
        widget.release,
        cancelToken: _cancel,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (mounted) {
        setState(
          () => _message = launched
              ? '请在系统安装界面确认升级，已有配置会保留。'
              : '请允许此应用安装更新，然后再次点击安装。',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _message = '更新失败或校验未通过，请稍后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('发现新版本 ${widget.release.version}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('更新来自你的 GitHub 仓库。升级会保留手机上的站点、下载器和其他配置。'),
        if (_progress != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(value: _progress),
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_message!),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_busy ? '取消' : '稍后'),
      ),
      FilledButton(
        onPressed: _busy ? null : _install,
        child: const Text('下载并安装'),
      ),
    ],
  );
}
