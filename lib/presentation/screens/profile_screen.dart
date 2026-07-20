import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/player.dart';
import '../../domain/repositories/player_repository.dart';
import '../controllers/auth_controller.dart';
import '../widgets/photo_viewer.dart';
import 'admin_management_screen.dart';
import 'auth_screen.dart';

/// Limite conservador para que la foto (ya en base64) quepa comoda dentro
/// del maximo de 1 MB por documento de Firestore junto con el resto de
/// los campos del jugador.
const _kMaxPhotoBytes = 250 * 1024;

const _kPrimaryGreen = Color(0xFF2E6B3F);

/// Pantalla de perfil: cambiar la foto (si la cuenta está vinculada a un
/// jugador de la liga) y cambiar la contraseña. Los invitados anónimos no
/// tienen correo, así que no se les muestra la sección de contraseña.
class ProfileScreen extends StatefulWidget {
  final Player? player;

  const ProfileScreen({super.key, required this.player});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingPhoto = false;
  bool _savingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final player = widget.player;
    if (player == null) return;
    final players = context.read<PlayerRepository>();
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 240,
      imageQuality: 70,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.length > _kMaxPhotoBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esa foto es muy pesada, prueba con otra.'),
          ),
        );
        return;
      }
      await players.updatePlayerPhoto(player.id, base64Encode(bytes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar la foto: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _forgotPassword() async {
    final auth = context.read<AuthController>();
    final email = auth.currentUser?.email;
    if (email == null) return;
    final error = await auth.sendPasswordResetEmail(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Te enviamos un correo para cambiar tu contraseña.',
        ),
      ),
    );
  }

  void _showForgotPasswordInfo() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Olvidaste tu contraseña?'),
        content: const Text(
          'Te enviaremos un correo para que puedas cambiarla. Revisa tu '
          'bandeja de entrada y, si no lo ves ahí, revisa también la '
          'carpeta de spam o correo no deseado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _editNameDialog(Player player) async {
    final players = context.read<PlayerRepository>();
    final fullNameController = TextEditingController(text: player.fullName);
    final shortNameController = TextEditingController(
      text: player.shortName ?? '',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar nombre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fullNameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: shortNameController,
              decoration: const InputDecoration(
                labelText: 'Apodo o nombre corto (opcional)',
                helperText: 'Así aparecerá en las listas y partidas',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final fullName = fullNameController.text.trim();
              if (fullName.isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                await players.updatePlayer(
                  player.id,
                  fullName,
                  shortName: shortNameController.text,
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No se pudo guardar: $e')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final auth = context.read<AuthController>();
    await auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _changePassword() async {
    final current = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa ambos campos de contraseña.')),
      );
      return;
    }
    if (newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas nuevas no coinciden.')),
      );
      return;
    }

    setState(() => _savingPassword = true);
    final auth = context.read<AuthController>();
    final error = await auth.changePassword(current, newPass);
    if (!mounted) return;
    setState(() => _savingPassword = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña actualizada correctamente.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialPlayer = widget.player;
    if (initialPlayer == null) return _buildScaffold(context, null);

    final players = context.read<PlayerRepository>();
    return StreamBuilder<Player?>(
      stream: players.watchPlayer(initialPlayer.id),
      initialData: initialPlayer,
      builder: (context, snapshot) {
        return _buildScaffold(context, snapshot.data ?? initialPlayer);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Player? player) {
    final auth = context.watch<AuthController>();
    final email = auth.currentUser?.email;
    final displayName = player?.displayName ?? email ?? 'Invitado';
    final hasEmailAccount = email != null && email.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: player?.photoBase64 != null
                      ? () => showFullPhoto(context, player!.photoBase64!)
                      : null,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: _kPrimaryGreen.withValues(alpha: 0.12),
                    backgroundImage: player?.photoBase64 != null
                        ? MemoryImage(base64Decode(player!.photoBase64!))
                        : null,
                    child: player?.photoBase64 == null
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 32,
                              color: _kPrimaryGreen,
                            ),
                          )
                        : null,
                  ),
                ),
                if (player != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: _kPrimaryGreen,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _uploadingPhoto ? null : _pickPhoto,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _uploadingPhoto
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              if (player != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Editar nombre',
                  onPressed: () => _editNameDialog(player),
                ),
              ],
            ],
          ),
          if (hasEmailAccount) ...[
            Center(
              child: Text(email, style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                auth.isAdmin ? 'Cuenta de administrador' : 'Cuenta de jugador',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _kPrimaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          if (hasEmailAccount) ...[
            const Text(
              'Cambiar contraseña',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrentPassword,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _newPasswordFocus.requestFocus(),
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrentPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(
                    () => _obscureCurrentPassword = !_obscureCurrentPassword,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              focusNode: _newPasswordFocus,
              obscureText: _obscureNewPassword,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
              decoration: InputDecoration(
                labelText: 'Contraseña nueva',
                helperText: 'Mínimo 6 caracteres',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(
                    () => _obscureNewPassword = !_obscureNewPassword,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocus,
              obscureText: _obscureConfirmPassword,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _changePassword(),
              decoration: InputDecoration(
                labelText: 'Repetir contraseña nueva',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _savingPassword ? null : _changePassword,
              child: _savingPassword
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Actualizar contraseña'),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  tooltip: 'Cómo funciona',
                  onPressed: _showForgotPasswordInfo,
                ),
              ],
            ),
          ] else
            const Text(
              'Estás jugando como invitado sin cuenta, así que no hay '
              'contraseña que cambiar.',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          if (auth.isAdmin) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Dar permisos de administrador'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminManagementScreen(),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                hasEmailAccount
                    ? 'Cerrar sesión'
                    : 'Salir del modo invitado y registrarme',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _signOut,
            ),
          ),
        ],
      ),
    );
  }
}
