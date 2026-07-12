import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/repositories/driver_verification_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/firebase_storage_service.dart';
import '../../../services/registration_draft_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/step_indicator.dart';

class LiveSelfieVerificationScreen extends StatefulWidget {
  const LiveSelfieVerificationScreen({super.key});

  @override
  State<LiveSelfieVerificationScreen> createState() =>
      _LiveSelfieVerificationScreenState();
}

class _LiveSelfieVerificationScreenState
    extends State<LiveSelfieVerificationScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  Uint8List? _selfieBytes;
  String? _cameraError;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  int _cameraSession = 0;
  final _storageService = FirebaseStorageService();
  final _verificationRepository = DriverVerificationRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed &&
        _selfieBytes == null &&
        _cameraController == null) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final session = ++_cameraSession;
    final previousController = _cameraController;
    _cameraController = null;
    await previousController?.dispose();

    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _cameraError = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCamera',
          'No camera was found on this device.',
        );
      }

      CameraDescription selectedCamera = cameras.first;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted || session != _cameraSession) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isInitializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted || session != _cameraSession) return;
      setState(() {
        _isInitializing = false;
        _cameraError = _cameraErrorMessage(error);
      });
    } catch (_) {
      if (!mounted || session != _cameraSession) return;
      setState(() {
        _isInitializing = false;
        _cameraError = 'The camera could not be started. Please try again.';
      });
    }
  }

  Future<void> _captureSelfie() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final selfie = await controller.takePicture();
      final bytes = await selfie.readAsBytes();
      if (bytes.isEmpty) {
        throw CameraException('EmptyCapture', 'The captured image was empty.');
      }
      if (!mounted) return;

      setState(() {
        _selfieBytes = bytes;
        _isCapturing = false;
      });
      RegistrationDraftService.instance.setSelfieBytes(bytes);
      await _releaseCamera();
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_cameraErrorMessage(error))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The selfie could not be captured. Please try again.'),
        ),
      );
    }
  }

  Future<void> _retakeSelfie() async {
    setState(() => _selfieBytes = null);
    await _initializeCamera();
  }

  Future<void> _useSelfie() async {
    final bytes = _selfieBytes;
    if (bytes == null || _isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });
    try {
      final uid = AuthService.instance.currentUserId;
      if (uid != null) {
        final path = await _storageService.uploadBytes(
          bytes: bytes,
          path: 'driver_verifications/$uid/selfie.jpg',
          onProgress: (progress) {
            if (mounted) setState(() => _uploadProgress = progress);
          },
        );
        RegistrationDraftService.instance.setSelfiePath(path, clearBytes: true);
        await _verificationRepository.saveSelfieDraft(
          uid: uid,
          selfiePath: path,
        );
      } else {
        RegistrationDraftService.instance.setSelfieBytes(bytes);
        if (mounted) setState(() => _uploadProgress = 1);
        RegistrationDraftService.instance.setSelfiePath(
          'live_selfie_pending.jpg',
        );
      }
      if (!mounted) return;
      Navigator.pushNamed(context, RouteNames.review);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _releaseCamera() async {
    _cameraSession++;
    final controller = _cameraController;
    _cameraController = null;
    await controller?.dispose();
  }

  String _cameraErrorMessage(CameraException error) {
    return switch (error.code) {
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' ||
      'CameraAccessRestricted' =>
        'Camera access is required. Allow camera access in your device settings, then try again.',
      'NoCamera' => 'No camera was found on this device.',
      _ => error.description ?? 'The camera could not be started.',
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraSession++;
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSelfie = _selfieBytes != null;

    return Scaffold(
      appBar: const DriverAppBar(
        title: 'Live Selfie Verification',
        showBack: true,
        showLogo: false,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepIndicator(current: 4),
              const SizedBox(height: 12),
              const Text(
                'Step 4 of 5',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate),
              ),
              const SizedBox(height: 8),
              Text(
                hasSelfie
                    ? 'Check that your face is clear before continuing.'
                    : 'Look into the front camera and take a live selfie.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _CameraFrame(
                controller: _cameraController,
                selfieBytes: _selfieBytes,
                isInitializing: _isInitializing,
                isCapturing: _isCapturing,
                errorMessage: _cameraError,
                onCapture: _captureSelfie,
                onRetry: _initializeCamera,
              ),
              const SizedBox(height: 18),
              if (_isUploading) ...[
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 7),
                Text(
                  'Securely uploading selfie '
                  '${(_uploadProgress * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.slate),
                ),
                const SizedBox(height: 12),
              ],
              const AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconWell(icon: Icons.shield_outlined),
                        SizedBox(width: 12),
                        Text(
                          'Tips for a great selfie',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    _SelfieTip(label: 'Remove sunglasses and face coverings'),
                    SizedBox(height: 8),
                    _SelfieTip(label: 'Make sure your face is well-lit'),
                    SizedBox(height: 8),
                    _SelfieTip(label: 'Keep your full face inside the guide'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (hasSelfie) ...[
                PrimaryButton(
                  label: 'Use this selfie and continue',
                  icon: Icons.check_rounded,
                  isLoading: _isUploading,
                  onPressed: _useSelfie,
                ),
                const SizedBox(height: 10),
                AppOutlineButton(
                  label: 'Retake Selfie',
                  icon: Icons.refresh_rounded,
                  onPressed: _isUploading ? null : _retakeSelfie,
                ),
              ] else
                const Text(
                  'Use the shutter button in the camera frame to take your selfie.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.slate),
                ),
              const SizedBox(height: 16),
              const Text(
                'Your selfie is encrypted and used only for identity verification.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.slate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraFrame extends StatelessWidget {
  const _CameraFrame({
    required this.controller,
    required this.selfieBytes,
    required this.isInitializing,
    required this.isCapturing,
    required this.errorMessage,
    required this.onCapture,
    required this.onRetry,
  });

  final CameraController? controller;
  final Uint8List? selfieBytes;
  final bool isInitializing;
  final bool isCapturing;
  final String? errorMessage;
  final VoidCallback onCapture;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 410,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildContent(),
            if (controller?.value.isInitialized == true &&
                selfieBytes == null) ...[
              const Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(child: _LiveBadge()),
              ),
              Center(
                child: Container(
                  width: 220,
                  height: 285,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(110),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 2,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(
                  child: _ShutterButton(
                    isCapturing: isCapturing,
                    onPressed: onCapture,
                  ),
                ),
              ),
            ],
            if (selfieBytes != null)
              const Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(child: _CapturedBadge()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final bytes = selfieBytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }

    if (isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 14),
            Text(
              'Starting front camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    final error = errorMessage;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 54,
            ),
            const SizedBox(height: 14),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Camera Again'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    final camera = controller;
    if (camera == null || !camera.value.isInitialized) {
      return const Center(
        child: Text(
          'Front camera unavailable',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final previewSize = camera.value.previewSize;
    if (previewSize == null) return CameraPreview(camera);

    return Center(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(camera),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: AppColors.danger),
          SizedBox(width: 7),
          Text(
            'LIVE FRONT CAMERA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapturedBadge extends StatelessWidget {
  const _CapturedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 17, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'SELFIE CAPTURED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.isCapturing, required this.onPressed});

  final bool isCapturing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take live selfie',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCapturing ? null : onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 74,
            height: 74,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.95),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(17),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelfieTip extends StatelessWidget {
  const _SelfieTip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          color: AppColors.primary,
          size: 19,
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(label)),
      ],
    );
  }
}
