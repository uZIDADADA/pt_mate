import 'package:flutter/material.dart';

Future<String?> requestBackupPassword(
  BuildContext context,
  bool encrypting,
) async {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  String? error;
  try {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(encrypting ? '加密备份' : '解密备份'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    encrypting
                        ? '设置至少 12 个字符的备份密码。请自行保存，恢复时需要此密码。'
                        : '输入创建此备份时使用的密码。',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(labelText: '备份密码'),
                  ),
                  if (encrypting)
                    TextField(
                      controller: confirmation,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(labelText: '再次输入密码'),
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (password.text.isEmpty ||
                      (encrypting && password.text.runes.length < 12)) {
                    setState(() => error = '备份密码至少需要 12 个字符');
                  } else if (encrypting && password.text != confirmation.text) {
                    setState(() => error = '两次密码不一致');
                  } else {
                    Navigator.pop(context, password.text);
                  }
                },
                child: const Text('继续'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    // Wait for the dialog's closing animation before disposing controllers.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    password.dispose();
    confirmation.dispose();
  }
}
