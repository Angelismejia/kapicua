import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/rule.dart';
import '../../domain/repositories/rules_repository.dart';
import '../controllers/auth_controller.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rules = context.read<RulesRepository>();
    final isAdmin = context.watch<AuthController>().isAdmin;

    return StreamBuilder<List<Rule>>(
      stream: rules.watchRules(),
      builder: (context, snapshot) {
        final ruleList = snapshot.data ?? [];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Reglas'),
            actions: [
              if (ruleList.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Compartir reglas',
                  onPressed: () => _showShareDialog(context, ruleList),
                ),
            ],
          ),
          body: snapshot.hasError
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No se pudieron cargar las reglas. Revisa tu '
                      'conexión e intenta de nuevo.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    if (isAdmin) ...[
                      _AddRuleCard(
                        onAdd: () => _showRuleDialog(context, rules),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (ruleList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('Todavía no hay reglas agregadas.'),
                        ),
                      )
                    else
                      for (var i = 0; i < ruleList.length; i++)
                        _ruleTile(context, rules, isAdmin, i + 1, ruleList[i]),
                  ],
                ),
        );
      },
    );
  }

  Widget _ruleTile(
    BuildContext context,
    RulesRepository rules,
    bool isAdmin,
    int number,
    Rule rule,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
          child: Text(
            '$number',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
        ),
        title: Text(rule.text),
        trailing: !isAdmin
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar',
                    onPressed: () =>
                        _showRuleDialog(context, rules, rule: rule),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Borrar',
                    onPressed: () => _confirmDelete(context, rules, rule),
                  ),
                ],
              ),
      ),
    );
  }

  void _showRuleDialog(
    BuildContext context,
    RulesRepository rules, {
    Rule? rule,
  }) {
    final controller = TextEditingController(text: rule?.text ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(rule == null ? 'Agregar regla' : 'Editar regla'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          minLines: 2,
          decoration: const InputDecoration(labelText: 'Texto de la regla'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              if (rule == null) {
                rules.addRule(text);
              } else {
                rules.updateRule(rule.id, text);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(BuildContext context, List<Rule> ruleList) {
    final shareKey = GlobalKey();
    showDialog(
      context: context,
      builder: (dialogContext) => _ShareRulesDialog(
        shareKey: shareKey,
        ruleList: ruleList,
      ),
    );
  }

  void _confirmDelete(BuildContext context, RulesRepository rules, Rule rule) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar regla'),
        content: const Text('¿Borrar esta regla? Esto no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              rules.deleteRule(rule.id);
              Navigator.pop(dialogContext);
            },
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }
}

class _AddRuleCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _AddRuleCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(Icons.rule_rounded, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reglas de la liga',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Agrega una nueva regla aquí.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onAdd,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Agregar',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vista previa de la imagen que se va a compartir, con el botón real de
/// compartir abajo. Se renderiza en pantalla (no oculto) porque
/// RepaintBoundary.toImage() necesita que el widget ya se haya pintado
/// al menos una vez — un widget "Offstage" nunca llega a pintarse.
class _ShareRulesDialog extends StatefulWidget {
  final GlobalKey shareKey;
  final List<Rule> ruleList;

  const _ShareRulesDialog({required this.shareKey, required this.ruleList});

  @override
  State<_ShareRulesDialog> createState() => _ShareRulesDialogState();
}

class _ShareRulesDialogState extends State<_ShareRulesDialog> {
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          widget.shareKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      await SharePlus.instance.share(
        ShareParams(
          text: 'Reglas de la liga en Kapicua',
          files: [
            XFile.fromData(
              bytes,
              name: 'reglas_kapicua.png',
              mimeType: 'image/png',
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo compartir: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      content: SingleChildScrollView(
        child: RepaintBoundary(
          key: widget.shareKey,
          child: _ShareableRulesCard(ruleList: widget.ruleList),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sharing ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: _sharing ? null : _share,
          icon: _sharing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.share, size: 18),
          label: const Text('Compartir'),
        ),
      ],
    );
  }
}

class _ShareableRulesCard extends StatelessWidget {
  final List<Rule> ruleList;

  const _ShareableRulesCard({required this.ruleList});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E6B3F);
    const lightGreen = Color(0xFFEAF6EB);
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'KAPICUA',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 3,
              color: green,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Reglas de la liga',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 21,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: green,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < ruleList.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ruleList[i].text,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5,
                      height: 1.35,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            if (i != ruleList.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
