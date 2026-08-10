import 'package:flutter/material.dart' hide Text;

import '../l10n/app_localizations.dart';
import '../models/account_profile.dart';
import '../models/app_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/localized_text.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.preferences, this.account});

  final AppPreferencesController preferences;
  final AccountProfileController? account;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int get _stepCount => widget.account == null ? 3 : 4;

  late String _residentType;
  late Set<String> _interests;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _residentType = widget.preferences.residentType;
    _interests = Set<String>.of(widget.preferences.interests);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 920;
    final compact = size.width < 380;
    final copy = _OnboardingCopy.forLocale(
      widget.preferences.locale.languageCode,
    );

    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _OnboardingBackdrop()),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : (isWide ? 32 : 18),
                vertical: compact ? 12 : (isWide ? 28 : 18),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 10,
                              child: _WelcomePanel(copy: copy),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 11,
                              child: _buildFlowCard(copy, compact: false),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CompactBrand(copy: copy),
                            const SizedBox(height: 16),
                            _buildFlowCard(copy, compact: compact),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowCard(_OnboardingCopy copy, {required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 17 : 26),
      decoration: BoxDecoration(
        color: AppThemeColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: AppThemeColors.border),
        boxShadow: [
          BoxShadow(
            color: AppThemeColors.shadow,
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FlowHeader(
            currentStep: _step,
            stepCount: _stepCount,
            stepLabel: copy.step,
            backLabel: copy.back,
            onBack: _step == 0 ? null : () => setState(() => _step -= 1),
          ),
          SizedBox(height: compact ? 24 : 30),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: const Offset(0.035, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: switch (_step) {
                0 => _LanguageStep(preferences: widget.preferences, copy: copy),
                1 => _ResidentStep(
                  selectedValue: _residentType,
                  copy: copy,
                  onSelected: (value) {
                    setState(() => _residentType = value);
                  },
                ),
                2 => _InterestsStep(
                  selectedValues: _interests,
                  copy: copy,
                  onChanged: (value, selected) {
                    setState(() {
                      selected
                          ? _interests.add(value)
                          : _interests.remove(value);
                    });
                  },
                ),
                _ => _AccountStep(account: widget.account!),
              },
            ),
          ),
          SizedBox(height: compact ? 24 : 30),
          SizedBox(
            height: 54,
            child: FilledButton(
              key: const ValueKey('onboarding-primary-action'),
              onPressed: _advance,
              style: FilledButton.styleFrom(
                backgroundColor: AppThemeColors.accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _step == _stepCount - 1
                          ? copy.startExploring
                          : AppLocalizations.of(context).text('continue'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Icon(
                    _step == _stepCount - 1
                        ? Icons.explore_rounded
                        : Icons.arrow_forward_rounded,
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _advance() {
    if (_step < _stepCount - 1) {
      setState(() => _step += 1);
      return;
    }

    widget.preferences.completeOnboarding(
      residentType: _residentType,
      interests: _interests,
    );
  }
}

class _AccountStep extends StatefulWidget {
  const _AccountStep({required this.account});

  final AccountProfileController account;

  @override
  State<_AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends State<_AccountStep> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _createMode = true;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _message;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    if (!widget.account.onlineAccountsAvailable) {
      return const _AccountUnavailable();
    }
    if (widget.account.isSignedIn) {
      return _SignedInAccount(account: widget.account);
    }

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _createMode ? 'Save your progress online' : 'Welcome back',
            style: TextStyle(
              color: AppThemeColors.text,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'An account is optional. Guests can still use maps, services, routes, scanning and a passport on this device.',
            style: TextStyle(color: AppThemeColors.subtleText, height: 1.45),
          ),
          const SizedBox(height: 18),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Create account')),
              ButtonSegment(value: false, label: Text('Sign in')),
            ],
            selected: {_createMode},
            onSelectionChanged: _busy
                ? null
                : (selection) => setState(() {
                    _createMode = selection.first;
                    _message = null;
                  }),
          ),
          const SizedBox(height: 16),
          if (_createMode) ...[
            TextField(
              controller: _nameController,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: strings.literal('Display name'),
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _emailController,
            autofillHints: const [AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: strings.literal('Email address'),
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            autofillHints: _createMode
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            obscureText: _obscurePassword,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: strings.literal('Password'),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: strings.literal(
                  _obscurePassword ? 'Show password' : 'Hide password',
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: TextStyle(
                color: _message!.startsWith('Check')
                    ? AppThemeColors.accentGreen
                    : Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _createMode
                        ? Icons.person_add_alt_1_rounded
                        : Icons.login_rounded,
                  ),
            label: Text(_createMode ? 'Create account' : 'Sign in'),
          ),
          if (!_createMode)
            TextButton(
              onPressed: _busy ? null : _resetPassword,
              child: const Text('Forgot password?'),
            ),
          const SizedBox(height: 6),
          Text(
            'You can continue as a guest using the button below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppThemeColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!email.contains('@') || password.length < 6) {
      setState(
        () => _message = 'Enter a valid email and 6+ character password.',
      );
      return;
    }
    if (_createMode && _nameController.text.trim().isEmpty) {
      setState(() => _message = 'Enter a display name.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_createMode) {
        final confirmationRequired = await widget.account.createAccount(
          name: _nameController.text,
          email: email,
          password: password,
        );
        if (confirmationRequired && mounted) {
          setState(() {
            _message = 'Check your email to confirm the account, then sign in.';
            _createMode = false;
          });
        }
      } else {
        await widget.account.signInWithPassword(
          email: email,
          password: password,
        );
      }
      if (mounted) setState(() {});
    } on Object catch (error) {
      if (mounted) setState(() => _message = _friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _message = 'Enter your email address first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.account.sendPasswordReset(email);
      if (mounted) {
        setState(() => _message = 'Check your email for a reset link.');
      }
    } on Object catch (error) {
      if (mounted) setState(() => _message = _friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyAuthError(Object error) {
    final source = error.toString().toLowerCase();
    return AppLocalizations.of(context).literal(
      source.contains('network') || source.contains('socket')
          ? 'The account service is unavailable right now. Please try again later.'
          : 'Sign-in failed. Check your details and try again.',
    );
  }
}

class _SignedInAccount extends StatelessWidget {
  const _SignedInAccount({required this.account});

  final AccountProfileController account;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: AppThemeColors.accentGreen,
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 14),
        Text(
          'Signed in as ${account.name}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppThemeColors.text,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(account.email, style: TextStyle(color: AppThemeColors.muted)),
        const SizedBox(height: 16),
        Text(
          'Your account is ready. Cloud passport sync will be enabled in the next data stage.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppThemeColors.subtleText, height: 1.45),
        ),
      ],
    );
  }
}

class _AccountUnavailable extends StatelessWidget {
  const _AccountUnavailable();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.cloud_off_rounded, color: AppThemeColors.muted, size: 48),
        const SizedBox(height: 14),
        Text(
          'Online accounts are not configured',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppThemeColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Continue as a guest. Sign-in becomes available when the app starts with its Supabase configuration.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppThemeColors.subtleText, height: 1.45),
        ),
      ],
    );
  }
}

class _OnboardingBackdrop extends StatelessWidget {
  const _OnboardingBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppThemeColors.background),
      child: AppThemeColors.isDark
          ? CustomPaint(painter: _BackdropPainter())
          : const SizedBox.expand(),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppThemeColors.accentGreen.withValues(alpha: 0.055)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 58);
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.12),
      180,
      paint,
    );

    paint.color = AppThemeColors.accentBlue.withValues(alpha: 0.075);
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.84),
      240,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.copy});

  final _OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: const Color(0xFF0D4F7C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppThemeColors.accentCyan.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandLockup(compact: false),
          const SizedBox(height: 64),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppThemeColors.accentGreen,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            copy.panelTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            copy.panelBody,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 30),
          _BenefitLine(
            icon: Icons.location_on_rounded,
            label: copy.findEssentials,
          ),
          const SizedBox(height: 16),
          _BenefitLine(icon: Icons.groups_rounded, label: copy.joinCommunity),
          const SizedBox(height: 16),
          _BenefitLine(icon: Icons.park_rounded, label: copy.exploreOutdoors),
          const SizedBox(height: 28),
          Row(
            children: [
              Icon(
                Icons.verified_user_rounded,
                color: AppThemeColors.accentGreen,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  copy.noAccount,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand({required this.copy});

  final _OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Expanded(child: _BrandLockup(compact: true)),
          const SizedBox(width: 12),
          Tooltip(
            message: copy.noAccount,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppThemeColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppThemeColors.border),
              ),
              child: Icon(
                Icons.shield_rounded,
                color: AppThemeColors.accentGreen,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 48 : 62,
          height: compact ? 48 : 62,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(compact ? 16 : 20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 12 : 15),
            child: Image.asset(
              'assets/images/canada_bay_logo.jpg',
              fit: BoxFit.contain,
              semanticLabel: AppLocalizations.of(
                context,
              ).literal('City of Canada Bay logo'),
            ),
          ),
        ),
        SizedBox(width: compact ? 11 : 14),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore Canada Bay',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: compact ? AppThemeColors.text : Colors.white,
                  fontSize: compact ? 17 : 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'YOUR LOCAL COMMUNITY GUIDE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppThemeColors.accentGreen,
                  fontSize: compact ? 8 : 9,
                  letterSpacing: compact ? 0.9 : 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BenefitLine extends StatelessWidget {
  const _BenefitLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: AppThemeColors.accentGreen, size: 20),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _FlowHeader extends StatelessWidget {
  const _FlowHeader({
    required this.currentStep,
    required this.stepCount,
    required this.stepLabel,
    required this.backLabel,
    required this.onBack,
  });

  final int currentStep;
  final int stepCount;
  final String stepLabel;
  final String backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (onBack != null) ...[
              Semantics(
                button: true,
                label: backLabel,
                child: InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          color: AppThemeColors.muted,
                          size: 19,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          backLabel,
                          style: TextStyle(
                            color: AppThemeColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
            Text(
              '$stepLabel ${currentStep + 1} / $stepCount',
              style: TextStyle(
                color: AppThemeColors.subtleText,
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          children: List.generate(stepCount, (index) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: index == currentStep ? 5 : 4,
                margin: EdgeInsets.only(right: index == stepCount - 1 ? 0 : 7),
                decoration: BoxDecoration(
                  color: index <= currentStep
                      ? AppThemeColors.accentGreen
                      : AppThemeColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({required this.preferences, required this.copy});

  final AppPreferencesController preferences;
  final _OnboardingCopy copy;

  static const _languages = <_LanguageOption>[
    _LanguageOption(
      code: 'en',
      monogram: 'EN',
      nativeName: 'English',
      englishName: 'English',
    ),
    _LanguageOption(
      code: 'zh',
      monogram: '中',
      nativeName: '简体中文',
      englishName: 'Simplified Chinese',
    ),
    _LanguageOption(
      code: 'ko',
      monogram: '한',
      nativeName: '한국어',
      englishName: 'Korean',
    ),
    _LanguageOption(
      code: 'it',
      monogram: 'IT',
      nativeName: 'Italiano',
      englishName: 'Italian',
    ),
    _LanguageOption(
      code: 'hi',
      monogram: 'हि',
      nativeName: 'हिन्दी',
      englishName: 'Hindi',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          eyebrow: copy.welcome,
          title: copy.languageTitle,
          body: copy.languageBody,
        ),
        const SizedBox(height: 22),
        _ResponsiveChoiceGrid(
          children: _languages.map((language) {
            return _LanguageCard(
              option: language,
              selected: preferences.locale.languageCode == language.code,
              selectedLabel: copy.selected,
              onTap: () => preferences.setLocale(Locale(language.code)),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _InformationNote(
          icon: Icons.lock_outline_rounded,
          title: copy.privateTitle,
          body: copy.privateBody,
        ),
      ],
    );
  }
}

class _ResidentStep extends StatelessWidget {
  const _ResidentStep({
    required this.selectedValue,
    required this.copy,
    required this.onSelected,
  });

  final String selectedValue;
  final _OnboardingCopy copy;
  final ValueChanged<String> onSelected;

  static const _options = <_ResidentOption>[
    _ResidentOption(
      value: 'New resident',
      labelKey: 'newResident',
      icon: Icons.home_rounded,
    ),
    _ResidentOption(
      value: 'Student',
      labelKey: 'student',
      icon: Icons.school_rounded,
    ),
    _ResidentOption(
      value: 'Family',
      labelKey: 'family',
      icon: Icons.family_restroom_rounded,
    ),
    _ResidentOption(
      value: 'Young professional',
      labelKey: 'professional',
      icon: Icons.work_rounded,
    ),
    _ResidentOption(
      value: 'Retiree',
      labelKey: 'retiree',
      icon: Icons.wb_sunny_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          eyebrow: copy.makeItYours,
          title: strings.text('aboutYou'),
          body: copy.residentBody,
        ),
        const SizedBox(height: 22),
        _ResponsiveChoiceGrid(
          children: _options.map((option) {
            return _SelectionCard(
              icon: option.icon,
              label: strings.text(option.labelKey),
              selected: selectedValue == option.value,
              onTap: () => onSelected(option.value),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        _InformationNote(
          icon: Icons.tune_rounded,
          title: copy.personalisedTitle,
          body: copy.personalisedBody,
        ),
      ],
    );
  }
}

class _InterestsStep extends StatelessWidget {
  const _InterestsStep({
    required this.selectedValues,
    required this.copy,
    required this.onChanged,
  });

  final Set<String> selectedValues;
  final _OnboardingCopy copy;
  final void Function(String value, bool selected) onChanged;

  static const _options = <_InterestOption>[
    _InterestOption(
      value: 'Community',
      labelKey: 'communityInterest',
      icon: Icons.groups_rounded,
    ),
    _InterestOption(
      value: 'Outdoors',
      labelKey: 'outdoorsInterest',
      icon: Icons.directions_walk_rounded,
    ),
    _InterestOption(
      value: 'Environment',
      labelKey: 'environmentInterest',
      icon: Icons.eco_rounded,
    ),
    _InterestOption(
      value: 'Local food',
      labelKey: 'foodInterest',
      icon: Icons.restaurant_rounded,
    ),
    _InterestOption(
      value: 'Local services',
      labelKey: 'servicesInterest',
      icon: Icons.info_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          eyebrow: copy.finalStep,
          title: strings.text('interests'),
          body: copy.interestsBody,
        ),
        const SizedBox(height: 22),
        _ResponsiveChoiceGrid(
          children: _options.map((option) {
            final selected = selectedValues.contains(option.value);
            return _SelectionCard(
              icon: option.icon,
              label: strings.text(option.labelKey),
              selected: selected,
              onTap: () => onChanged(option.value, !selected),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        _InformationNote(
          icon: Icons.auto_awesome_rounded,
          title: copy.readyTitle,
          body: selectedValues.isEmpty
              ? copy.readyEmptyBody
              : copy.readyBody(selectedValues.length),
          accent: true,
        ),
      ],
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: AppThemeColors.accentGreen,
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          title,
          style: TextStyle(
            color: AppThemeColors.text,
            fontSize: 29,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.65,
          ),
        ),
        const SizedBox(height: 11),
        Text(
          body,
          style: TextStyle(
            color: AppThemeColors.subtleText,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ResponsiveChoiceGrid extends StatelessWidget {
  const _ResponsiveChoiceGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 410 ? 2 : 1;
        const gap = 10.0;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.option,
    required this.selected,
    required this.selectedLabel,
    required this.onTap,
  });

  final _LanguageOption option;
  final bool selected;
  final String selectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.nativeName}, ${strings.literal(option.englishName)}',
      child: Material(
        color: selected
            ? AppThemeColors.accentGreen.withValues(alpha: 0.12)
            : AppThemeColors.surfaceAlt.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('language-${option.code}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppThemeColors.accentGreen
                    : AppThemeColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppThemeColors.accentGreen
                        : AppThemeColors.surfaceStrong,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    option.monogram,
                    style: TextStyle(
                      color: selected ? Colors.white : AppThemeColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.nativeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppThemeColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (option.nativeName != option.englishName) ...[
                        const SizedBox(height: 2),
                        Text(
                          option.englishName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppThemeColors.subtleText,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: selected
                      ? Tooltip(
                          key: const ValueKey('selected'),
                          message: selectedLabel,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: AppThemeColors.accentGreen,
                            size: 21,
                          ),
                        )
                      : const SizedBox(key: ValueKey('unselected'), width: 21),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? AppThemeColors.accentGreen.withValues(alpha: 0.12)
            : AppThemeColors.surfaceAlt.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            constraints: const BoxConstraints(minHeight: 66),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppThemeColors.accentGreen
                    : AppThemeColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppThemeColors.accentGreen
                        : AppThemeColors.surfaceStrong,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : AppThemeColors.muted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: AppThemeColors.text,
                      fontSize: 13,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.check_rounded,
                    color: AppThemeColors.accentGreen,
                    size: 17,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InformationNote extends StatelessWidget {
  const _InformationNote({
    required this.icon,
    required this.title,
    required this.body,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent
            ? AppThemeColors.accentGreen.withValues(alpha: 0.1)
            : AppThemeColors.surfaceStrong.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent
              ? AppThemeColors.accentGreen.withValues(alpha: 0.32)
              : AppThemeColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: AppThemeColors.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppThemeColors.accentGreen, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppThemeColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    color: AppThemeColors.subtleText,
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption({
    required this.code,
    required this.monogram,
    required this.nativeName,
    required this.englishName,
  });

  final String code;
  final String monogram;
  final String nativeName;
  final String englishName;
}

class _ResidentOption {
  const _ResidentOption({
    required this.value,
    required this.labelKey,
    required this.icon,
  });

  final String value;
  final String labelKey;
  final IconData icon;
}

class _InterestOption {
  const _InterestOption({
    required this.value,
    required this.labelKey,
    required this.icon,
  });

  final String value;
  final String labelKey;
  final IconData icon;
}

class _OnboardingCopy {
  const _OnboardingCopy({
    required this.welcome,
    required this.languageTitle,
    required this.languageBody,
    required this.selected,
    required this.step,
    required this.back,
    required this.makeItYours,
    required this.residentBody,
    required this.finalStep,
    required this.interestsBody,
    required this.privateTitle,
    required this.privateBody,
    required this.personalisedTitle,
    required this.personalisedBody,
    required this.readyTitle,
    required this.readyEmptyBody,
    required this.readyBodyBuilder,
    required this.startExploring,
    required this.panelTitle,
    required this.panelBody,
    required this.findEssentials,
    required this.joinCommunity,
    required this.exploreOutdoors,
    required this.noAccount,
  });

  final String welcome;
  final String languageTitle;
  final String languageBody;
  final String selected;
  final String step;
  final String back;
  final String makeItYours;
  final String residentBody;
  final String finalStep;
  final String interestsBody;
  final String privateTitle;
  final String privateBody;
  final String personalisedTitle;
  final String personalisedBody;
  final String readyTitle;
  final String readyEmptyBody;
  final String Function(int count) readyBodyBuilder;
  final String startExploring;
  final String panelTitle;
  final String panelBody;
  final String findEssentials;
  final String joinCommunity;
  final String exploreOutdoors;
  final String noAccount;

  String readyBody(int count) => readyBodyBuilder(count);

  static _OnboardingCopy forLocale(String languageCode) {
    return switch (languageCode) {
      'zh' => _zh,
      'ko' => _ko,
      'it' => _it,
      'hi' => _hi,
      _ => _en,
    };
  }

  static final _en = _OnboardingCopy(
    welcome: 'Welcome',
    languageTitle: 'Choose the language that feels right',
    languageBody:
        'This changes app guidance and navigation. Official place names always stay the same.',
    selected: 'Selected',
    step: 'STEP',
    back: 'Back',
    makeItYours: 'Make it yours',
    residentBody:
        'A little context helps us make your home screen useful from day one.',
    finalStep: 'Nearly there',
    interestsBody:
        'Choose as many as you like. We will bring the most useful local discoveries forward.',
    privateTitle: 'Private by default',
    privateBody:
        'Your language and choices are saved on this device. No account is needed to begin.',
    personalisedTitle: 'Recommendations, not labels',
    personalisedBody:
        'This only tunes what you see first. Every place, event and service remains available.',
    readyTitle: 'Your local guide is ready',
    readyEmptyBody:
        'You can continue without choosing anything and browse everything.',
    readyBodyBuilder: (count) =>
        '$count interest${count == 1 ? '' : 's'} will shape your first recommendations.',
    startExploring: 'Start exploring',
    panelTitle: 'Feel at home, sooner.',
    panelBody:
        'One trusted guide to local services, community life and the places that make Canada Bay special.',
    findEssentials: 'Find everyday services with confidence',
    joinCommunity: 'Discover events, clubs and volunteering',
    exploreOutdoors: 'Explore parks, routes and local nature',
    noAccount: 'No account or personal details needed to get started',
  );

  static final _zh = _OnboardingCopy(
    welcome: '欢迎',
    languageTitle: '选择您熟悉的语言',
    languageBody: '这会更改应用指南和导航。官方地名将保持不变。',
    selected: '已选择',
    step: '步骤',
    back: '返回',
    makeItYours: '为您定制',
    residentBody: '简单介绍您的情况，以便我们从第一天起提供实用内容。',
    finalStep: '即将完成',
    interestsBody: '可多选。我们会优先展示对您最有帮助的本地信息。',
    privateTitle: '默认保护隐私',
    privateBody: '您的语言和选择仅保存在此设备上。开始使用无需账户。',
    personalisedTitle: '推荐，而非定义',
    personalisedBody: '这只会调整首页内容的顺序。所有地点、活动和服务仍可查看。',
    readyTitle: '您的本地指南已准备就绪',
    readyEmptyBody: '您可以不做选择，继续浏览全部内容。',
    readyBodyBuilder: (count) => '将根据您选择的 $count 项兴趣提供初始推荐。',
    startExploring: '开始探索',
    panelTitle: '更快融入本地生活。',
    panelBody: '一个可信赖的指南，汇集本地服务、社区生活和加拿大湾的特色地点。',
    findEssentials: '轻松查找日常服务',
    joinCommunity: '发现活动、社团和志愿服务',
    exploreOutdoors: '探索公园、路线和本地自然',
    noAccount: '开始使用无需账户或个人资料',
  );

  static final _ko = _OnboardingCopy(
    welcome: '환영합니다',
    languageTitle: '편한 언어를 선택하세요',
    languageBody: '앱 안내와 메뉴 언어가 변경됩니다. 공식 장소명은 그대로 유지됩니다.',
    selected: '선택됨',
    step: '단계',
    back: '뒤로',
    makeItYours: '나에게 맞게',
    residentBody: '간단한 정보로 첫날부터 더 유용한 홈 화면을 만들어 드립니다.',
    finalStep: '거의 완료',
    interestsBody: '여러 개를 선택해도 됩니다. 유용한 지역 정보를 먼저 보여 드립니다.',
    privateTitle: '개인정보 우선',
    privateBody: '언어와 선택 항목은 이 기기에 저장됩니다. 시작할 때 계정은 필요하지 않습니다.',
    personalisedTitle: '구분이 아닌 추천',
    personalisedBody: '처음 보이는 순서만 조정됩니다. 모든 장소, 행사와 서비스는 계속 이용할 수 있습니다.',
    readyTitle: '지역 가이드가 준비됐습니다',
    readyEmptyBody: '선택하지 않고 계속해서 모든 내용을 둘러볼 수 있습니다.',
    readyBodyBuilder: (count) => '선택한 관심사 $count개로 첫 추천을 준비합니다.',
    startExploring: '탐색 시작',
    panelTitle: '더 빨리 우리 동네처럼.',
    panelBody: '지역 서비스, 커뮤니티 생활과 캐나다 베이의 특별한 장소를 한곳에서 만나세요.',
    findEssentials: '생활에 필요한 서비스를 쉽게 찾기',
    joinCommunity: '행사, 모임과 봉사활동 발견하기',
    exploreOutdoors: '공원, 산책로와 자연 탐방하기',
    noAccount: '시작할 때 계정이나 개인정보가 필요하지 않습니다',
  );

  static final _it = _OnboardingCopy(
    welcome: 'Benvenuto',
    languageTitle: 'Scegli la lingua che preferisci',
    languageBody:
        'La guida e la navigazione cambieranno lingua. I nomi ufficiali dei luoghi restano invariati.',
    selected: 'Selezionata',
    step: 'PASSAGGIO',
    back: 'Indietro',
    makeItYours: 'Personalizza',
    residentBody:
        'Qualche informazione ci aiuta a rendere utile la schermata iniziale fin dal primo giorno.',
    finalStep: 'Ci siamo quasi',
    interestsBody:
        'Scegli tutte le opzioni che vuoi. Daremo priorità alle scoperte locali più utili.',
    privateTitle: 'Privacy fin dall’inizio',
    privateBody:
        'Lingua e preferenze restano su questo dispositivo. Non serve un account per iniziare.',
    personalisedTitle: 'Consigli, non etichette',
    personalisedBody:
        'Cambia solo ciò che vedi per primo. Tutti i luoghi, gli eventi e i servizi restano disponibili.',
    readyTitle: 'La tua guida locale è pronta',
    readyEmptyBody:
        'Puoi continuare senza scegliere nulla ed esplorare tutti i contenuti.',
    readyBodyBuilder: (count) =>
        '$count interess${count == 1 ? 'e' : 'i'} guiderann${count == 1 ? 'à' : 'o'} i primi consigli.',
    startExploring: 'Inizia a esplorare',
    panelTitle: 'Sentiti a casa, prima.',
    panelBody:
        'Una guida affidabile a servizi locali, vita di comunità e luoghi speciali di Canada Bay.',
    findEssentials: 'Trova con facilità i servizi quotidiani',
    joinCommunity: 'Scopri eventi, gruppi e volontariato',
    exploreOutdoors: 'Esplora parchi, percorsi e natura',
    noAccount: 'Nessun account o dato personale richiesto per iniziare',
  );

  static final _hi = _OnboardingCopy(
    welcome: 'स्वागत है',
    languageTitle: 'अपनी सुविधाजनक भाषा चुनें',
    languageBody:
        'इससे ऐप का मार्गदर्शन और नेविगेशन बदलेगा। आधिकारिक स्थान नाम वही रहेंगे।',
    selected: 'चुनी गई',
    step: 'चरण',
    back: 'वापस',
    makeItYours: 'अपने अनुसार बनाएँ',
    residentBody:
        'थोड़ी सी जानकारी पहले दिन से आपकी होम स्क्रीन को उपयोगी बनाती है।',
    finalStep: 'लगभग पूरा',
    interestsBody:
        'आप एक से अधिक चुन सकते हैं। हम उपयोगी स्थानीय जानकारी पहले दिखाएँगे।',
    privateTitle: 'गोपनीयता सबसे पहले',
    privateBody:
        'आपकी भाषा और विकल्प इसी डिवाइस पर रहते हैं। शुरू करने के लिए खाता ज़रूरी नहीं है।',
    personalisedTitle: 'सुझाव, पहचान नहीं',
    personalisedBody:
        'यह केवल पहले दिखने वाली सामग्री तय करता है। सभी स्थान, कार्यक्रम और सेवाएँ उपलब्ध रहेंगी।',
    readyTitle: 'आपकी स्थानीय गाइड तैयार है',
    readyEmptyBody: 'बिना कुछ चुने भी आप आगे बढ़कर सब कुछ देख सकते हैं।',
    readyBodyBuilder: (count) =>
        'आपकी $count रुचियों से शुरुआती सुझाव तैयार होंगे।',
    startExploring: 'खोजना शुरू करें',
    panelTitle: 'जल्दी अपनापन महसूस करें।',
    panelBody:
        'स्थानीय सेवाओं, सामुदायिक जीवन और कनाडा बे की खास जगहों के लिए एक भरोसेमंद गाइड।',
    findEssentials: 'रोज़मर्रा की सेवाएँ आसानी से खोजें',
    joinCommunity: 'कार्यक्रम, समूह और स्वयंसेवा खोजें',
    exploreOutdoors: 'पार्क, रास्ते और स्थानीय प्रकृति देखें',
    noAccount: 'शुरू करने के लिए खाते या निजी जानकारी की ज़रूरत नहीं',
  );
}
