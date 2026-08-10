import 'package:flutter/material.dart' hide Text;

import '../l10n/app_localizations.dart';
import '../models/account_profile.dart';
import '../models/app_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/localized_text.dart';

const _brandBlue = Color(0xFF0D4F7C);
Color get _profileAccent => AppThemeColors.accentGreen;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.controller, this.preferences});

  final AccountProfileController controller;
  final AppPreferencesController? preferences;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preferences == null
          ? controller
          : Listenable.merge([controller, preferences!]),
      builder: (context, _) {
        final palette = _ProfilePalette.of(context);

        return Scaffold(
          backgroundColor: palette.background,
          body: ColoredBox(
            color: palette.background,
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= 900;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      desktop ? 32 : 16,
                      desktop ? 28 : 18,
                      desktop ? 32 : 16,
                      28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ProfileHero(
                              controller: controller,
                              palette: palette,
                              desktop: desktop,
                              onEditName: () => _editName(context),
                            ),
                            const SizedBox(height: 18),
                            if (desktop)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildAccountColumn(
                                      context,
                                      palette,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: _buildSettingsColumn(
                                      context,
                                      palette,
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _buildAccountColumn(context, palette),
                              const SizedBox(height: 14),
                              _buildSettingsColumn(context, palette),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountColumn(BuildContext context, _ProfilePalette palette) {
    return Column(
      children: [
        _ProfilePanel(
          palette: palette,
          icon: Icons.badge_outlined,
          title: 'Device profile',
          subtitle: controller.isSignedIn
              ? 'Your local identity on this device'
              : 'Personalise your experience on this device',
          child: Column(
            children: [
              _AccountIdentityRow(controller: controller, palette: palette),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _editDeviceProfile(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _profileAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: const StadiumBorder(),
                  ),
                  icon: Icon(
                    controller.isSignedIn
                        ? Icons.edit_rounded
                        : Icons.person_add_alt_1_rounded,
                  ),
                  label: Text(
                    controller.isSignedIn
                        ? 'Edit device profile'
                        : 'Set up device profile',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This is a local profile, not secure cloud authentication. '
                'Its details are stored on this device and do not sync.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 10.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ProfilePanel(
          palette: palette,
          icon: Icons.devices_rounded,
          title: 'Profile storage',
          subtitle: 'Know where your information is kept',
          child: Column(
            children: [
              _InformationRow(
                palette: palette,
                icon: Icons.phone_android_rounded,
                title: 'Stored on this device',
                subtitle:
                    'Cloud backup and account recovery are not connected yet.',
              ),
              if (controller.isSignedIn) ...[
                Divider(color: palette.border, height: 10),
                _ActionRow(
                  palette: palette,
                  icon: Icons.logout_rounded,
                  title: 'Leave device profile',
                  subtitle: 'Return this device to Guest mode',
                  onTap: () => _confirmSignOut(context),
                  showDivider: false,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsColumn(BuildContext context, _ProfilePalette palette) {
    return Column(
      children: [
        _ProfilePanel(
          palette: palette,
          icon: Icons.palette_outlined,
          title: 'Appearance',
          subtitle: 'Choose how Explore Canada Bay looks',
          child: _ThemeSelector(controller: controller, palette: palette),
        ),
        const SizedBox(height: 14),
        _ProfilePanel(
          palette: palette,
          icon: Icons.translate_rounded,
          title: AppLocalizations.of(context).text('language'),
          subtitle: 'Choose the interface language for this device',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LanguageSelector(
                preferences: preferences,
                palette: palette,
                fallbackLocale: AppLocalizations.of(context).locale,
              ),
              const SizedBox(height: 14),
              Divider(color: palette.border, height: 10),
              _ActionRow(
                palette: palette,
                icon: Icons.auto_awesome_rounded,
                title: 'Replay welcome setup',
                subtitle: preferences == null
                    ? 'App preferences are not connected on this screen'
                    : 'Review your language, interests and newcomer profile',
                onTap: preferences == null
                    ? null
                    : () => _confirmReplayOnboarding(context),
                showDivider: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ProfilePanel(
          palette: palette,
          icon: Icons.visibility_outlined,
          title: 'Passport display',
          subtitle: 'Choose what appears when you show your passport',
          child: Column(
            children: [
              _PrivacySwitch(
                palette: palette,
                icon: controller.profileVisible
                    ? Icons.badge_rounded
                    : Icons.visibility_off_rounded,
                title: 'Show profile name',
                subtitle: controller.profileVisible
                    ? 'Use your display name on the Community Passport'
                    : 'Use the neutral Explorer label on the passport',
                value: controller.profileVisible,
                onChanged: controller.setProfileVisible,
              ),
              _PrivacySwitch(
                palette: palette,
                icon: Icons.workspace_premium_outlined,
                title: 'Show achievements',
                subtitle: controller.profileVisible
                    ? 'Display your chosen rare achievements'
                    : 'Hidden while your profile name is hidden',
                value: controller.showAchievements,
                onChanged: controller.profileVisible
                    ? controller.setShowAchievements
                    : null,
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editName(BuildContext context) async {
    final textController = TextEditingController(text: controller.name);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final strings = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: const Text('What should we call you?'),
          content: TextField(
            controller: textController,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: strings.literal('Display name'),
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(textController.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    textController.dispose();
    if (result != null) {
      await controller.updateName(result);
    }
  }

  Future<void> _editDeviceProfile(BuildContext context) async {
    if (controller.onlineAccountsAvailable && !controller.isSignedIn) {
      await showDialog<void>(
        context: context,
        builder: (_) => _ProfileAuthDialog(controller: controller),
      );
      return;
    }

    final nameController = TextEditingController(
      text: controller.isSignedIn ? controller.name : '',
    );
    final emailController = TextEditingController(
      text: controller.isSignedIn ? controller.email : '',
    );
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<_DeviceProfileDraft>(
      context: context,
      builder: (dialogContext) {
        final strings = AppLocalizations.of(dialogContext);
        return AlertDialog(
          icon: const Icon(Icons.phone_android_rounded),
          title: Text(
            controller.isSignedIn
                ? 'Edit device profile'
                : 'Set up a device profile',
          ),
          content: SizedBox(
            width: 430,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: _profileAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'Local profile only. This does not sign you into a '
                        'secure online account, and it cannot be recovered on '
                        'another device.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: strings.literal('Display name'),
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return strings.literal('Enter a display name');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: strings.literal('Email identifier'),
                        helperText: strings.literal(
                          'Used only to separate local passport progress.',
                        ),
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (value) => _validateEmail(context, value),
                      onFieldSubmitted: (_) {
                        if (formKey.currentState?.validate() ?? false) {
                          Navigator.of(dialogContext).pop(
                            _DeviceProfileDraft(
                              name: nameController.text,
                              email: emailController.text,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(
                    _DeviceProfileDraft(
                      name: nameController.text,
                      email: emailController.text,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save locally'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    if (result == null) return;

    await controller.applyAuthenticatedProfile(
      name: result.name,
      email: result.email,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Device profile saved locally.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.logout_rounded),
          title: const Text('Return to Guest mode?'),
          content: const Text(
            'This signs out of the online account on this device. Guest mode '
            'will remain available and keeps separate local passport progress.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Return to Guest'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await controller.signOut();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This device is now using the Guest profile.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmReplayOnboarding(BuildContext context) async {
    final appPreferences = preferences;
    if (appPreferences == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.auto_awesome_rounded),
          title: const Text('Replay welcome setup?'),
          content: const Text(
            'You can review your language, interests and newcomer profile. '
            'Your passport progress will not be changed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Replay setup'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await appPreferences.resetOnboarding();
    }
  }

  static String? _validateEmail(BuildContext context, String? value) {
    final strings = AppLocalizations.of(context);
    final email = value?.trim() ?? '';
    if (email.isEmpty) return strings.literal('Enter an email identifier');

    final at = email.indexOf('@');
    final dot = email.lastIndexOf('.');
    if (at <= 0 || dot <= at + 1 || dot >= email.length - 1) {
      return strings.literal('Enter a valid email address');
    }
    return null;
  }
}

class _ProfileAuthDialog extends StatefulWidget {
  const _ProfileAuthDialog({required this.controller});

  final AccountProfileController controller;

  @override
  State<_ProfileAuthDialog> createState() => _ProfileAuthDialogState();
}

class _ProfileAuthDialogState extends State<_ProfileAuthDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.cloud_outlined),
      title: Text(_create ? 'Create account' : 'Sign in'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_create) ...[
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: strings.literal('Display name'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: strings.literal('Email address'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: strings.literal('Password'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _create = !_create;
                        _error = null;
                      }),
                child: Text(
                  _create
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy ? 'Please wait…' : (_create ? 'Create' : 'Sign in'),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_email.text.contains('@') || _password.text.length < 6) {
      setState(() => _error = 'Enter a valid email and 6+ character password.');
      return;
    }
    if (_create && _name.text.trim().isEmpty) {
      setState(() => _error = 'Enter a display name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_create) {
        final confirmation = await widget.controller.createAccount(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
        if (confirmation) {
          if (mounted) {
            setState(() {
              _create = false;
              _error = 'Check your email, confirm the account, then sign in.';
            });
          }
          return;
        }
      } else {
        await widget.controller.signInWithPassword(
          email: _email.text,
          password: _password.text,
        );
      }
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        final source = error.toString().toLowerCase();
        setState(
          () => _error = AppLocalizations.of(context).literal(
            source.contains('network') || source.contains('socket')
                ? 'The account service is unavailable right now. Please try again later.'
                : 'Sign-in failed. Check your details and try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _DeviceProfileDraft {
  const _DeviceProfileDraft({required this.name, required this.email});

  final String name;
  final String email;
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.controller,
    required this.palette,
    required this.desktop,
    required this.onEditName,
  });

  final AccountProfileController controller;
  final _ProfilePalette palette;
  final bool desktop;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(desktop ? 26 : 20),
      decoration: BoxDecoration(
        color: _brandBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: desktop ? 82 : 68,
            height: desktop ? 82 : 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                _initials(controller.name),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: desktop ? 26 : 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(width: desktop ? 20 : 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(
                    context,
                  ).message('helloName', {'name': controller.name}),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: desktop ? 31 : 23,
                    height: 1.05,
                    letterSpacing: -0.7,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  controller.isSignedIn
                      ? 'Device profile • ${controller.email}'
                      : AppLocalizations.of(context).text('profileAdventure'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: desktop ? 13 : 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: AppLocalizations.of(context).literal('Edit display name'),
            onPressed: onEditName,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'E';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

class _AccountIdentityRow extends StatelessWidget {
  const _AccountIdentityRow({required this.controller, required this.palette});

  final AccountProfileController controller;
  final _ProfilePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.softSurface,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _profileAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              controller.isSignedIn
                  ? Icons.badge_rounded
                  : Icons.person_outline_rounded,
              color: _profileAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.isSignedIn ? controller.email : 'Guest explorer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  controller.isSignedIn
                      ? 'Saved locally on this device'
                      : 'Progress is stored on this device',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(label: controller.isSignedIn ? 'DEVICE' : 'GUEST'),
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.preferences,
    required this.palette,
    required this.fallbackLocale,
  });

  static const _languages = <String, String>{
    'en': 'English',
    'zh': '简体中文',
    'ko': '한국어',
    'it': 'Italiano',
    'hi': 'हिन्दी',
  };

  final AppPreferencesController? preferences;
  final _ProfilePalette palette;
  final Locale fallbackLocale;

  @override
  Widget build(BuildContext context) {
    final selectedCode =
        preferences?.locale.languageCode ?? fallbackLocale.languageCode;
    final enabled = preferences != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _languages.entries.map((entry) {
            return ChoiceChip(
              selected: selectedCode == entry.key,
              onSelected: enabled
                  ? (_) => preferences!.setLocale(Locale(entry.key))
                  : null,
              avatar: selectedCode == entry.key
                  ? const Icon(Icons.check_rounded, size: 17)
                  : null,
              label: Text(entry.value),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w800,
                color: selectedCode == entry.key ? Colors.white : palette.text,
              ),
              selectedColor: _profileAccent,
              backgroundColor: palette.softSurface,
              disabledColor: palette.softSurface,
              side: BorderSide(color: palette.border),
              showCheckmark: false,
            );
          }).toList(),
        ),
        if (!enabled) ...[
          const SizedBox(height: 10),
          Text(
            'Language changes require app preferences to be connected.',
            style: TextStyle(
              color: palette.muted,
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.controller, required this.palette});

  final AccountProfileController controller;
  final _ProfilePalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;

        return SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
              value: ThemeMode.light,
              icon: compact ? null : const Icon(Icons.light_mode_rounded),
              label: const Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: compact ? null : const Icon(Icons.dark_mode_rounded),
              label: const Text('Dark'),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              icon: compact ? null : const Icon(Icons.settings_suggest_rounded),
              label: Text(compact ? 'Auto' : 'System'),
            ),
          ],
          selected: {controller.themeMode},
          onSelectionChanged: (selection) {
            controller.setThemeMode(selection.first);
          },
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          style: ButtonStyle(
            visualDensity: VisualDensity.comfortable,
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : palette.muted,
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? _profileAccent
                  : palette.softSurface,
            ),
            side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
          ),
        );
      },
    );
  }
}

class _PrivacySwitch extends StatelessWidget {
  const _PrivacySwitch({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  final _ProfilePalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          secondary: _SettingIcon(icon: icon, palette: palette),
          title: Text(
            title,
            style: TextStyle(
              color: onChanged == null
                  ? palette.muted.withValues(alpha: 0.7)
                  : palette.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              subtitle,
              style: TextStyle(
                color: palette.muted,
                fontSize: 10,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeTrackColor: _profileAccent,
        ),
        if (showDivider) Divider(color: palette.border, height: 10),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  final _ProfilePalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _SettingIcon(icon: icon, palette: palette),
          title: Text(
            title,
            style: TextStyle(
              color: onTap == null
                  ? palette.muted.withValues(alpha: 0.75)
                  : palette.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: palette.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: onTap == null
              ? Icon(
                  Icons.info_outline_rounded,
                  color: palette.muted.withValues(alpha: 0.65),
                )
              : Icon(Icons.chevron_right_rounded, color: palette.muted),
          onTap: onTap,
        ),
        if (showDivider) Divider(color: palette.border, height: 8),
      ],
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final _ProfilePalette palette;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _SettingIcon(icon: icon, palette: palette),
      title: Text(
        title,
        style: TextStyle(
          color: palette.text,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          subtitle,
          style: TextStyle(
            color: palette.muted,
            fontSize: 10,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final _ProfilePalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.96),
        border: Border(
          left: BorderSide(color: _profileAccent, width: 3),
          top: BorderSide(color: palette.border),
          bottom: BorderSide(color: palette.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SettingIcon(icon: icon, palette: palette),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({required this.icon, required this.palette});

  final IconData icon;
  final _ProfilePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _profileAccent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: _profileAccent, size: 20),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _profileAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _profileAccent,
          fontSize: 8,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProfilePalette {
  const _ProfilePalette({
    required this.isDark,
    required this.background,
    required this.glow,
    required this.surface,
    required this.softSurface,
    required this.text,
    required this.muted,
    required this.border,
  });

  final bool isDark;
  final Color background;
  final Color glow;
  final Color surface;
  final Color softSurface;
  final Color text;
  final Color muted;
  final Color border;

  factory _ProfilePalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return isDark
        ? const _ProfilePalette(
            isDark: true,
            background: Color(0xFF061C31),
            glow: Color(0xFF0B3655),
            surface: Color(0xFF0B2A45),
            softSurface: Color(0xFF123653),
            text: Color(0xFFF4F9FD),
            muted: Color(0xFF79BFD0),
            border: Color(0x332587D9),
          )
        : const _ProfilePalette(
            isDark: false,
            background: Color(0xFFF1F7F8),
            glow: Color(0xFFD8F3EC),
            surface: Colors.white,
            softSurface: Color(0xFFF0F5F6),
            text: Color(0xFF102A3A),
            muted: Color(0xFF607D8B),
            border: Color(0x1F0D4F7C),
          );
  }
}
