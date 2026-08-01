import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
          appBar: AppBar(title: const Text('Reglas')),
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
