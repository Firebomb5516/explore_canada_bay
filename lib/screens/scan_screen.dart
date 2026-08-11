import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/app_localizations.dart';
import '../l10n/journey_localizations.dart';
import '../models/passport.dart';
import '../services/external_link_service.dart';
import '../theme/app_theme.dart';
import '../widgets/localized_text.dart';

const _scanBlue = Color(0xFF0D4F7C);
Color get _scanGreen => AppThemeColors.accentGreen;
Color get _scanDark => AppThemeColors.background;
Color get _scanCard => AppThemeColors.surface;
Color get _scanText => AppThemeColors.text;
Color get _scanMuted => AppThemeColors.muted;
const _scanAccent = Color(0xFF2179C8);
const _scanInk = Color(0xFF061C31);
const _logoAsset = 'assets/images/canada_bay_logo.jpg';

bool get _isDesktopPlatform =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;

const _demoPayload =
    '{"namespace":"explore_canada_bay.passport","version":1,'
    '"rewardId":"demo-canada-bay-club-01","place":"Canada Bay Club",'
    '"xp":50,"badge":{"id":"food_finder","name":"Food Finder",'
    '"description":"Discover local food and cafe favourites.",'
    '"category":"Food","icon":"restaurant","color":"#FFB74D",'
    '"target":5,"progress":1}}';

enum _RewardDialogAction { scanAnother, viewPassport }

class ScanScreen extends StatefulWidget {
  final PassportController passport;
  final bool isActive;
  final VoidCallback? onOpenPassport;

  const ScanScreen({
    super.key,
    required this.passport,
    required this.isActive,
    this.onOpenPassport,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  late final MobileScannerController _scannerController =
      MobileScannerController(
        autoStart: false,
        detectionSpeed: DetectionSpeed.noDuplicates,
        detectionTimeoutMs: 750,
        formats: [BarcodeFormat.qrCode],
        facing: CameraFacing.back,
      );

  bool _processing = false;
  bool _manualEntryOpen = false;
  bool _disposing = false;
  late bool _appIsResumed;
  Future<void> _cameraOperation = Future<void>.value();

  bool get _cameraCanRun =>
      mounted &&
      !_disposing &&
      !_isDesktopPlatform &&
      widget.isActive &&
      _appIsResumed &&
      !_processing &&
      !_manualEntryOpen;

  @override
  void initState() {
    super.initState();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appIsResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive && _appIsResumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_startScanner());
      });
    }
  }

  @override
  void didUpdateWidget(covariant ScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;

    if (widget.isActive && _appIsResumed) {
      // Wait until the active scanner widget has been mounted before opening
      // the camera. The inactive tab never builds a MobileScanner widget.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_startScanner());
      });
    } else {
      unawaited(_stopScanner());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isResumed = state == AppLifecycleState.resumed;
    if (_appIsResumed != isResumed) {
      setState(() => _appIsResumed = isResumed);
    }

    if (widget.isActive && isResumed) {
      // Wait for MobileScanner to be mounted again after the lifecycle rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_startScanner());
      });
    } else {
      unawaited(_stopScanner());
    }
  }

  Future<void> _startScanner() async {
    await _queueCameraUpdate();
  }

  Future<void> _stopScanner() async {
    await _queueCameraUpdate();
  }

  Future<void> _queueCameraUpdate() {
    // Serialising controller calls prevents a slow stop from winning a race
    // against a newer start when users switch tabs quickly.
    _cameraOperation = _cameraOperation.then((_) => _applyCameraState());
    return _cameraOperation;
  }

  Future<void> _applyCameraState() async {
    try {
      if (_cameraCanRun) {
        await _scannerController.start();
        if (!_cameraCanRun) {
          await _scannerController.stop();
        }
      } else {
        await _scannerController.stop();
      }
    } on Object {
      // The scanner widget's errorBuilder presents permission/device errors.
    }
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (!_cameraCanRun) return;

    String? rawValue;
    for (final barcode in capture.barcodes) {
      if (barcode.format == BarcodeFormat.qrCode &&
          barcode.rawValue?.trim().isNotEmpty == true) {
        rawValue = barcode.rawValue;
        break;
      }
    }

    if (rawValue == null) return;
    await _processPayload(rawValue);
  }

  Future<void> _processPayload(String rawValue) async {
    if (_processing || !mounted || !widget.isActive) return;

    setState(() => _processing = true);
    await _stopScanner();
    var restartScanner = true;

    try {
      final result = await widget.passport.applyQrPayload(rawValue);
      if (!mounted) return;
      if (!result.duplicate) {
        await Future.wait<void>([
          SystemSound.play(SystemSoundType.click),
          HapticFeedback.mediumImpact(),
        ]);
        if (!mounted) return;
      }
      final action = await _showRewardResult(result);
      if (action == _RewardDialogAction.viewPassport &&
          widget.onOpenPassport != null) {
        restartScanner = false;
        widget.onOpenPassport!.call();
      }
    } on FormatException catch (error) {
      if (!mounted) return;
      await _showInvalidCode(
        AppLocalizations.of(context).qrError(error.message.toString()),
      );
    } catch (error) {
      if (!mounted) return;
      await _showInvalidCode(
        'This reward could not be saved. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        if (restartScanner && widget.isActive) {
          unawaited(_startScanner());
        }
      }
    }
  }

  Future<void> _showManualEntry() async {
    if (!mounted || !widget.isActive || _processing || _manualEntryOpen) {
      return;
    }

    _manualEntryOpen = true;
    await _stopScanner();
    if (!mounted) return;

    String? payload;
    final textController = TextEditingController();
    try {
      payload = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxWidth: 650,
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
                  ),
                  margin: EdgeInsets.all(14),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _scanDark,
                    borderRadius: BorderRadius.circular(29),
                    border: Border.all(
                      color: _scanAccent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _ScanIconBox(
                              icon: Icons.keyboard_rounded,
                              colour: _scanGreen,
                            ),
                            SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                'Enter a reward code',
                                style: TextStyle(
                                  color: _scanText,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: AppLocalizations.of(
                                sheetContext,
                              ).literal('Close'),
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: Icon(
                                Icons.close_rounded,
                                color: _scanMuted,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Paste the text stored inside a passport QR code. This is useful on a simulator or desktop.',
                          style: TextStyle(
                            color: _scanMuted,
                            fontSize: 11.5,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: 14),
                        TextField(
                          controller: textController,
                          minLines: 4,
                          maxLines: 7,
                          autofocus: true,
                          style: TextStyle(color: _scanText, fontSize: 12),
                          decoration: InputDecoration(
                            hintText:
                                '{"namespace":"explore_canada_bay.passport", ...}',
                            hintStyle: TextStyle(
                              color: _scanMuted.withValues(alpha: 0.55),
                            ),
                            filled: true,
                            fillColor: _scanCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: 13),
                        Wrap(
                          spacing: 9,
                          runSpacing: 9,
                          children: [
                            if (kDebugMode) ...[
                              OutlinedButton.icon(
                                onPressed: () {
                                  textController.text = _demoPayload;
                                },
                                icon: Icon(Icons.science_outlined),
                                label: Text('Use demo reward'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  textController.text =
                                      PassportController.debugUnlockAllCode;
                                },
                                icon: Icon(Icons.developer_mode_rounded),
                                label: Text('Unlock all badges'),
                              ),
                            ],
                            FilledButton.icon(
                              onPressed: () {
                                final value = textController.text.trim();
                                if (value.isEmpty) return;
                                Navigator.pop(sheetContext, value);
                              },
                              icon: Icon(Icons.redeem_rounded),
                              label: Text('Claim reward'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } finally {
      textController.dispose();
      _manualEntryOpen = false;
    }

    if (!mounted) return;
    if (payload == null) {
      if (widget.isActive) unawaited(_startScanner());
      return;
    }
    await _processPayload(payload);
  }

  Future<_RewardDialogAction?> _showRewardResult(PassportRewardResult result) {
    final badge = result.badge;
    final colour = result.duplicate
        ? _scanMuted
        : result.badgeJustEarned
        ? Colors.orangeAccent
        : _scanGreen;

    return showDialog<_RewardDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final strings = AppLocalizations.of(dialogContext);
        final languageCode = Localizations.localeOf(dialogContext).languageCode;
        final badgeName = badge?.localizedName(languageCode);
        final rewardPlaceName = result.reward.rewardId == 'debug-unlock-all'
            ? JourneyLocalizations.of(dialogContext).ui('developerTools')
            : result.reward.placeName;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 460,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.88,
            ),
            padding: EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: _scanCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colour.withValues(alpha: 0.48)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: colour.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      result.duplicate
                          ? Icons.replay_rounded
                          : result.badgeJustEarned
                          ? Icons.workspace_premium_rounded
                          : Icons.check_circle_rounded,
                      color: colour,
                      size: 43,
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    result.duplicate
                        ? 'Already collected'
                        : result.badgeJustEarned
                        ? 'Badge unlocked!'
                        : 'Discovery collected!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _scanText,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    strings.rewardMessage(
                      placeName: rewardPlaceName,
                      xp: result.xpAwarded,
                      duplicate: result.duplicate,
                      badgeJustEarned: result.badgeJustEarned,
                      badgeName: badgeName,
                      badgeProgress: badge?.progress,
                      badgeTarget: badge?.target,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _scanMuted,
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (result.reward.content != null) ...[
                    SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _scanGreen.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _scanGreen.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.reward.content!.category.toUpperCase(),
                            style: TextStyle(
                              color: _scanGreen,
                              fontSize: 8.5,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            result.reward.content!.title,
                            style: TextStyle(
                              color: _scanText,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            result.reward.content!.body,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _scanMuted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                          if (result.reward.content!.officialUrl != null) ...[
                            SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () async {
                                final url = result.reward.content!.officialUrl!;
                                final opened = await const ExternalLinkService()
                                    .open(url);
                                if (!mounted || opened) return;
                                await Clipboard.setData(
                                  ClipboardData(text: url),
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'The link could not open, so it was copied instead.',
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.open_in_new_rounded, size: 17),
                              label: Text('Open official source'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (!result.duplicate) ...[
                    SizedBox(height: 17),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (result.xpAwarded > 0)
                          _RewardPill(
                            icon: Icons.bolt_rounded,
                            label: '+${result.xpAwarded} XP',
                            colour: _scanGreen,
                          ),
                        if (badge != null)
                          _RewardPill(
                            icon: result.badgeJustEarned
                                ? Icons.workspace_premium_rounded
                                : Icons.trending_up_rounded,
                            label: result.badgeJustEarned
                                ? badge.localizedName(languageCode)
                                : '${badge.localizedName(languageCode)} '
                                      '${badge.progress}/${badge.target}',
                            colour: Colors.orangeAccent,
                          ),
                      ],
                    ),
                  ],
                  SizedBox(height: 23),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            _RewardDialogAction.scanAnother,
                          ),
                          child: Text('Scan another'),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            _RewardDialogAction.viewPassport,
                          ),
                          child: Text('View passport'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInvalidCode(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _scanCard,
          scrollable: true,
          icon: Icon(
            Icons.qr_code_2_rounded,
            color: Colors.orangeAccent,
            size: 38,
          ),
          title: Text('Not a passport code'),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: _scanMuted, height: 1.4),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Try again'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposing = true;
    unawaited(_disposeScanner());
    super.dispose();
  }

  Future<void> _disposeScanner() async {
    await _stopScanner();
    await _scannerController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scanDark,
      body: ColoredBox(
        color: AppThemeColors.background,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 900;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 30 : 16,
                  desktop ? 24 : 16,
                  desktop ? 30 : 16,
                  120,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 1120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ScanHeader(),
                        SizedBox(height: desktop ? 24 : 18),
                        if (_isDesktopPlatform)
                          _DesktopInstallPrompt(compact: !desktop)
                        else if (desktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: _buildScanner()),
                              SizedBox(width: 22),
                              Expanded(flex: 4, child: _buildInstructions()),
                            ],
                          )
                        else ...[
                          _buildScanner(),
                          SizedBox(height: 16),
                          _buildInstructions(),
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
  }

  Widget _buildScanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _scanCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _scanAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.isActive && _appIsResumed)
                    MobileScanner(
                      controller: _scannerController,
                      tapToFocus: true,
                      onDetect: _handleCapture,
                      errorBuilder: (context, _) {
                        return _CameraUnavailable(
                          message: AppLocalizations.of(context).literal(
                            'Camera access is unavailable on this device.',
                          ),
                          onManualEntry: _showManualEntry,
                        );
                      },
                    )
                  else
                    ColoredBox(color: _scanInk),
                  IgnorePointer(
                    child: CustomPaint(painter: _ScanFramePainter()),
                  ),
                  if (_processing)
                    ColoredBox(
                      color: _scanInk.withValues(alpha: 0.72),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: _scanGreen),
                            SizedBox(height: 14),
                            Text(
                              'Checking reward…',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _scannerController,
                          builder: (context, state, _) {
                            final enabled = state.torchState == TorchState.on;
                            return _ScannerControl(
                              icon: enabled
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              label: 'Torch',
                              active: enabled,
                              onTap: _scannerController.toggleTorch,
                            );
                          },
                        ),
                        SizedBox(width: 10),
                        _ScannerControl(
                          icon: Icons.keyboard_rounded,
                          label: 'Enter code',
                          onTap: _showManualEntry,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.center_focus_strong_rounded,
                color: _scanGreen,
                size: 17,
              ),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Hold the passport QR code inside the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _scanText,
                    fontSize: 11,
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

  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: AppThemeColors.surfaceAlt,
        border: Border(
          left: BorderSide(color: _scanGreen, width: 3),
          top: BorderSide(color: _scanAccent.withValues(alpha: 0.22)),
          bottom: BorderSide(color: _scanAccent.withValues(alpha: 0.22)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScanIconBox(icon: Icons.explore_rounded, colour: _scanGreen),
          SizedBox(height: 16),
          Text(
            'Turn real places into passport rewards',
            style: TextStyle(
              color: _scanText,
              fontSize: 23,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Scan official signs at parks, environmental sites, heritage '
            'places, libraries, council facilities and community events.',
            style: TextStyle(
              color: _scanMuted,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 20),
          _ScanBenefit(
            icon: Icons.bolt_rounded,
            title: 'Earn XP',
            message: 'Level up your local explorer profile.',
          ),
          _ScanBenefit(
            icon: Icons.trending_up_rounded,
            title: 'Build badge progress',
            message: 'Complete themed discovery collections.',
          ),
          _ScanBenefit(
            icon: Icons.menu_book_rounded,
            title: 'Unlock local stories',
            message: 'Reveal trusted place information and learning content.',
          ),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _scanGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_rounded, color: _scanGreen, size: 20),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Rewards are saved to your passport and each official QR '
                    'reward can only be collected once.',
                    style: TextStyle(
                      color: _scanText,
                      fontSize: 10.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
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

class _ScanHeader extends StatelessWidget {
  const _ScanHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              _logoAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.sailing_rounded, color: _scanBlue),
            ),
          ),
        ),
        SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).text('scanDiscover'),
                style: TextStyle(
                  color: _scanText,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'YOUR NEXT REWARD IS OUT THERE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _scanMuted,
                  fontSize: 9,
                  letterSpacing: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopInstallPrompt extends StatelessWidget {
  const _DesktopInstallPrompt({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 24 : 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_scanBlue, _scanInk],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _scanInk.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Flex(
        direction: compact ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: compact
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: compact ? 72 : 92,
            height: compact ? 72 : 92,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_iphone_rounded,
              color: Colors.white,
              size: compact ? 36 : 46,
            ),
          ),
          SizedBox(width: compact ? 0 : 30, height: compact ? 24 : 0),
          if (compact) _buildMessage() else Expanded(child: _buildMessage()),
        ],
      ),
    );
  }

  Widget _buildMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Continue on your mobile',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 24 : 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Explore the community in person by installing the Explore '
          'Canada Bay app on your mobile device. Use your phone to scan '
          'signs, collect XP and unlock passport badges as you visit.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 16,
            height: 1.55,
          ),
        ),
        SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _DesktopBenefit(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan local signs',
            ),
            _DesktopBenefit(
              icon: Icons.stars_rounded,
              label: 'Earn XP and badges',
            ),
            _DesktopBenefit(
              icon: Icons.explore_rounded,
              label: 'Explore Canada Bay',
            ),
          ],
        ),
      ],
    );
  }
}

class _DesktopBenefit extends StatelessWidget {
  const _DesktopBenefit({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _scanGreen, size: 18),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ScanBenefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ScanBenefit({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          _ScanIconBox(icon: icon, colour: _scanGreen),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _scanText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    color: _scanMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
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

class _ScanIconBox extends StatelessWidget {
  final IconData icon;
  final Color colour;

  const _ScanIconBox({required this.icon, required this.colour});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.13),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: colour, size: 21),
    );
  }
}

class _ScannerControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ScannerControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _scanGreen : _scanInk.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 17),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color colour;

  const _RewardPill({
    required this.icon,
    required this.label,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colour, size: 16),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colour,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  final String message;
  final VoidCallback onManualEntry;

  const _CameraUnavailable({
    required this.message,
    required this.onManualEntry,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppThemeColors.surfaceAlt,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined, color: _scanMuted, size: 45),
              SizedBox(height: 12),
              Text(
                'Camera unavailable',
                style: TextStyle(
                  color: _scanText,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _scanMuted,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 15),
              FilledButton.icon(
                onPressed: onManualEntry,
                icon: Icon(Icons.keyboard_rounded),
                label: Text('Enter code instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameSize = size.shortestSide * 0.64;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 8),
      width: frameSize,
      height: frameSize,
    );
    final shadePath = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      shadePath,
      Paint()..color = _scanInk.withValues(alpha: 0.45),
    );

    final cornerPaint = Paint()
      ..color = _scanGreen
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final length = 38.0;

    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + length)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.left + length, rect.top),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - length, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.top + length),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rect.right, rect.bottom - length)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.right - length, rect.bottom),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rect.left + length, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.bottom - length),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
