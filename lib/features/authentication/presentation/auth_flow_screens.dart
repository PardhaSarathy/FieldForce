import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/errors.dart';
import '../../../data/repositories/mock_repositories.dart' show AuthException;
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/states.dart';
import 'widgets/brand_mark.dart';

/// Boot screen. Resolves the stored session, then hands off to the router's
/// redirect. Deliberately quiet — a splash should not animate for longer than
/// the work it is covering.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrandMark(size: 64),
            SizedBox(height: AppSpacing.xxxl),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple scaffold shared by the password-recovery steps.
class _AuthStepScaffold extends StatelessWidget {
  const _AuthStepScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppTypography.h1),
                const SizedBox(height: AppSpacing.sm),
                Text(subtitle, style: AppTypography.bodySm),
                const SizedBox(height: AppSpacing.xxl),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_controller.text.trim());
      if (!mounted) return;
      setState(() => _busy = false);
      context.push(Routes.otp, extra: _controller.text.trim());
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readablePostgrestError(
              e,
              fallback: 'Could not send the verification code. Try again.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthStepScaffold(
      title: 'Reset your password',
      subtitle:
          'Enter your Employee ID. We will send a verification code to '
          'the mobile number registered with your account.',
      children: [
        Form(
          key: _formKey,
          child: AppTextField(
            label: 'Employee ID',
            hint: 'e.g. MR1001',
            controller: _controller,
            required: true,
            prefixIcon: Icons.badge_outlined,
            textCapitalization: TextCapitalization.characters,
            // The keyboard's own return key submits, as it does on the sign-in
            // screen. Without it the rep types the code, presses Go, nothing
            // happens, and they have to dismiss the keyboard to reach a button
            // the keyboard is covering.
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: (v) => Validate.required(v, 'Employee ID'),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Send verification code',
          isLoading: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.employeeCode});

  final String employeeCode;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ok = await ref
          .read(authRepositoryProvider)
          .verifyOtp(employeeCode: widget.employeeCode, otp: _controller.text);

      if (!mounted) return;
      setState(() => _busy = false);

      if (ok) {
        context.push(Routes.resetPassword, extra: widget.employeeCode);
      } else {
        setState(() => _error = 'That code is not correct. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readablePostgrestError(
              e,
              fallback: 'Could not verify the code. Try again.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthStepScaffold(
      title: 'Enter verification code',
      subtitle:
          'We sent a 6-digit code to the number registered for '
          '${widget.employeeCode}. In this demo build the code is 123456.',
      children: [
        AppTextField(
          label: 'Verification code',
          hint: '6-digit code',
          controller: _controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          prefixIcon: Icons.pin_outlined,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _verify(),
          helper: _error,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: AppTypography.caption.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(label: 'Verify', isLoading: _busy, onPressed: _verify),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () => showComingWithBackend(context, 'Resending the code'),
          child: const Text('Resend code'),
        ),
      ],
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.employeeCode});

  final String employeeCode;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _done = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(
            employeeCode: widget.employeeCode,
            password: _password.text,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readablePostgrestError(
              e,
              fallback: 'Could not update the password. Try again.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SuccessState(
            title: 'Password updated',
            message: 'You can now sign in with your new password.',
            primaryLabel: 'Back to sign in',
            onPrimary: () => context.go(Routes.login),
          ),
        ),
      );
    }

    return _AuthStepScaffold(
      title: 'Create a new password',
      subtitle: 'Choose a password of at least 8 characters.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                textInputAction: TextInputAction.next,
                label: 'New password',
                controller: _password,
                obscureText: true,
                required: true,
                prefixIcon: Icons.lock_outline,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 8) {
                    return 'Use at least 8 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                label: 'Confirm password',
                controller: _confirm,
                obscureText: true,
                required: true,
                prefixIcon: Icons.lock_outline,
                validator: (v) =>
                    v == _password.text ? null : 'Passwords do not match',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Update password',
          isLoading: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// First sign-in with a password a manager set.
///
/// Not [ResetPasswordScreen]: that one is reached while signed out and ends at
/// the login form. This one is reached signed in, has nowhere to go back to —
/// the router holds the rep here — and ends on Home. Signing out is the only
/// other way off it.
class ChoosePasswordScreen extends ConsumerStatefulWidget {
  const ChoosePasswordScreen({super.key});

  @override
  ConsumerState<ChoosePasswordScreen> createState() =>
      _ChoosePasswordScreenState();
}

class _ChoosePasswordScreenState extends ConsumerState<ChoosePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      // On success the router sees the prompt cleared and moves on to Home.
      await ref
          .read(authControllerProvider.notifier)
          .chooseOwnPassword(_password.text);
    } on AuthException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } catch (e) {
      if (mounted) {
        setState(
          () => _problem = readablePostgrestError(
            e,
            fallback: 'Could not save that password. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Choose your own password', style: AppTypography.h1),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your manager set the password you just used. Pick one only '
                  'you know — you will sign in with it from now on.',
                  style: AppTypography.bodySm,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        textInputAction: TextInputAction.next,
                        label: 'New password',
                        controller: _password,
                        obscureText: true,
                        required: true,
                        prefixIcon: Icons.lock_outline,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (v.length < 8) return 'Use at least 8 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        label: 'Confirm password',
                        controller: _confirm,
                        obscureText: true,
                        required: true,
                        prefixIcon: Icons.lock_outline,
                        validator: (v) => v == _password.text
                            ? null
                            : 'Passwords do not match',
                      ),
                    ],
                  ),
                ),
                if (_problem != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _problem!,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Save password',
                  isLoading: _busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => ref.read(authControllerProvider.notifier).logout(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when a protected call is refused. Distinct from the login screen so
/// the user understands they were signed out rather than never signed in.
class SessionExpiredScreen extends ConsumerWidget {
  const SessionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.warningSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.timer_off_outlined,
                    size: 28,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Session expired', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'For your security you have been signed out. '
                  'Any work saved on this device is safe.',
                  style: AppTypography.bodySm,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Sign in again',
                  expand: false,
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
