import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import 'widgets/brand_mark.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController(text: 'MR1001');
  final _passwordController = TextEditingController(text: 'demo1234');
  bool _obscure = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Tapping a demo account signs straight in as that role.
  ///
  /// Filling the field and leaving the user to press the button invited exactly
  /// the failure this replaced: a stray keystroke turned "ASM201" into
  /// "ASM201s" and the form rejected it. Nothing here needs typing.
  Future<void> _signInAsDemoAccount(String code) async {
    ref.read(authControllerProvider.notifier).clearError();

    // Assign through `value` rather than `.text`: setting `.text` alone leaves
    // the selection at offset 0, so any later keystroke lands before the ID.
    _codeController.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );

    if (_passwordController.text.trim().isEmpty) {
      _passwordController.text = 'demo1234';
    }

    await _submit();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .login(_codeController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isBusy = state is AuthAuthenticating;
    final failure = state is AuthFailure ? state.message : null;
    final notice = state is AuthUnauthenticated ? state.message : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The brand is the subject of this page, so it is centred
                    // along with the greeting; the form below stays
                    // left-aligned, because field labels must be.
                    const Center(child: BrandMark(size: 56, centered: true)),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Welcome back',
                      style: AppTypography.h1,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Sign in to continue to Mr Sales.',
                      style: AppTypography.bodySm,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    if (notice != null) ...[
                      _Notice(message: notice, tone: AppColors.info),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    AppTextField(
                      label: 'Employee ID',
                      hint: 'e.g. MR1001',
                      controller: _codeController,
                      required: true,
                      enabled: !isBusy,
                      prefixIcon: Icons.badge_outlined,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      validator: (v) => Validate.required(v, 'Employee ID'),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    AppTextField(
                      label: 'Password',
                      hint: 'Enter your password',
                      controller: _passwordController,
                      required: true,
                      enabled: !isBusy,
                      obscureText: _obscure,
                      prefixIcon: Icons.lock_outline,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      validator: (v) => Validate.required(v, 'Password'),
                      suffix: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: AppSizes.iconMd,
                        ),
                        color: AppColors.textSecondary,
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),

                    if (failure != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _Notice(message: failure, tone: AppColors.error),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'Sign in',
                      isLoading: isBusy,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: isBusy
                          ? null
                          : () => context.push(Routes.forgotPassword),
                      child: const Text('Forgot password?'),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                    _DemoAccountsHint(
                      onPick: isBusy ? null : _signInAsDemoAccount,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.tone});

  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: AppSizes.iconMd, color: tone),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySm.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visible only because this build has no backend. The mock auth accepts any
/// seeded employee code, and surfacing them here is what makes the role matrix
/// explorable without documentation.
/// The accounts the login screen offers, and the one place they are listed.
///
/// Public so the test can assert against the *actual* panel rather than a
/// hand-copied twin. It was copied, the two drifted the moment the roles were
/// cut, and the test that existed to catch exactly that failed to compile
/// instead of failing to pass — so three dead rows shipped on the login
/// screen and nothing said a word.
const demoAccounts = <(String, String)>[
  ('MR1001', 'Field representative'),
  ('ASM201', 'Area sales manager'),
];

class _DemoAccountsHint extends StatelessWidget {
  const _DemoAccountsHint({this.onPick});

  /// Tapping a row signs in as that account. Typing codes to switch roles is
  /// friction nobody needs while reviewing a demo build — and it is where
  /// typos come from.
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    // Two, because there are two.
    //
    // This listed five, and the last three signed in as accounts that had been
    // removed with the roles — a row that looks like every other row, and
    // fails. The rule this breaks is the one the app is strictest about: a
    // control that cannot act must still answer. Here the honest answer is not
    // a message, it is deletion — RSM, NSM and Administrator are not roles
    // somebody could be given, they are roles that no longer exist.
    const accounts = demoAccounts;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.sandSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.sand.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DEMO ACCOUNTS', style: AppTypography.overline),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No backend is connected yet. Tap any account below to sign in as '
            'that role.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (code, role) in accounts)
            InkWell(
              onTap: onPick == null ? null : () => onPick!(code),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        code,
                        style: AppTypography.numeric.copyWith(fontSize: 12),
                      ),
                    ),
                    Expanded(child: Text(role, style: AppTypography.caption)),
                    const Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: AppColors.brand,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
