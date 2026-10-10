import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all fields"),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Authentication failed"),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("An error occurred: $e"),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F4),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 380;
            final panelMinHeight = constraints.maxHeight > 24
                ? constraints.maxHeight - 24
                : 0.0;

            return Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _DottedBackdropPainter()),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 20,
                      vertical: 12,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 474,
                        minHeight: panelMinHeight,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(color: const Color(0xFFD9D5D1)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF4C4036,
                              ).withValues(alpha: .08),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFFF3EF),
                                  Color(0xFFFFFBF8),
                                  Color(0xFFFFF7F2),
                                ],
                              ),
                            ),
                            child: Stack(
                              children: [
                                const Positioned.fill(
                                  child: CustomPaint(
                                    painter: _PanelGridPainter(),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    compact ? 18 : 22,
                                    24,
                                    compact ? 18 : 22,
                                    22,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _brandHeader(showSync: !compact),
                                      SizedBox(height: compact ? 34 : 44),
                                      _hero(),
                                      const SizedBox(height: 22),
                                      _featureBadge(compact: compact),
                                      SizedBox(height: compact ? 34 : 46),
                                      _loginCard(context, compact: compact),
                                      const SizedBox(height: 34),
                                      _footer(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _brandHeader({required bool showSync}) => Row(
    children: [
      _brandMark(size: 42),
      const SizedBox(width: 11),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SpendSense',
              style: TextStyle(
                color: Color(0xFF332C27),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -.3,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'LEDGER & INTELLIGENCE',
              style: TextStyle(
                color: Color(0xFF96796D),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.15,
              ),
            ),
          ],
        ),
      ),
      if (showSync)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF5EAE5).withValues(alpha: .85),
            border: Border.all(color: const Color(0xFFEEDBD1)),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, color: Color(0xFF18845E), size: 7),
              SizedBox(width: 7),
              Text(
                'Account sync',
                style: TextStyle(color: Color(0xFF66564D), fontSize: 11),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _brandMark({double size = 60}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEE7),
      borderRadius: BorderRadius.circular(size * .28),
      border: Border.all(color: const Color(0xFFFFB99F)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFF0542A).withValues(alpha: .08),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Icon(
      Icons.account_balance_wallet_rounded,
      color: const Color(0xFFFF5A1F),
      size: size * .45,
    ),
  );

  Widget _hero() => Column(
    children: [
      _brandMark(),
      const SizedBox(height: 17),
      const Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Welcome '),
            TextSpan(
              text: 'Back!',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Georgia',
          color: Color(0xFF28231F),
          fontSize: 38,
          height: 1.12,
          letterSpacing: -.8,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Login to continue managing your expenses',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF92796E), fontSize: 14, height: 1.5),
      ),
    ],
  );

  Widget _featureBadge({required bool compact}) => Container(
    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5F0).withValues(alpha: .9),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFFFC9B5)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFCC8D71).withValues(alpha: .08),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 9,
      children: [
        const Icon(Icons.circle, size: 6, color: Color(0xFFFF9C7C)),
        const Text(
          'Smart spending insights',
          style: TextStyle(
            color: Color(0xFFD94E2E),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(width: 3, height: 3, color: const Color(0xFFFFAA8D)),
        const Text(
          'Receipt scanning',
          style: TextStyle(color: Color(0xFF67544A), fontSize: 11),
        ),
      ],
    ),
  );

  Widget _loginCard(BuildContext context, {required bool compact}) => Container(
    padding: EdgeInsets.all(compact ? 17 : 22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF0E4DD)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF694D3D).withValues(alpha: .08),
          blurRadius: 20,
          offset: const Offset(0, 9),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _accountTabs(context),
        const SizedBox(height: 23),
        Row(
          children: const [
            _FieldLabel('Email address'),
            Spacer(),
            Text(
              'Primary ledger ID',
              style: TextStyle(color: Color(0xFF9A8175), fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Color(0xFF302923), fontSize: 14),
          decoration: _fieldDecoration(
            hint: 'Email address',
            icon: Icons.mail_outline_rounded,
          ),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Password'),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Color(0xFF302923), fontSize: 14),
          decoration: _fieldDecoration(
            hint: 'Password',
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF947B70),
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 19),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A1F),
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor: const Color(0xFFFF5A1F).withValues(alpha: .27),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: .1,
              ),
            ),
            onPressed: _isLoading ? null : _login,
            child: _isLoading
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Sign in to SpendSense'),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, size: 19),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 17),
        const Divider(color: Color(0xFFF0E4DD), height: 1),
        const SizedBox(height: 13),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              "Don't have an account?",
              style: TextStyle(color: Color(0xFF6E5B51), fontSize: 12),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF5A1F),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 36),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
              onPressed: _isLoading
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
              child: const Text('Start tracking free'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _accountTabs(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: const Color(0xFFF5EAE5),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF70574A).withValues(alpha: .09),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              'Sign In',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF302923),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _isLoading
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Create Account',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B7165), fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _footer() => Column(
    children: [
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights_outlined, color: Color(0xFF14835E), size: 15),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Transactions, categories & insights in one place',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8B7165), fontSize: 10),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      const Text(
        'Receipt scanning · Monthly spending trends',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFFAA9387), fontSize: 9),
      ),
    ],
  );
}

InputDecoration _fieldDecoration({
  required String hint,
  required IconData icon,
  Widget? suffixIcon,
}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xFFA58E82), fontSize: 14),
  prefixIcon: Icon(icon, color: const Color(0xFF9A8175), size: 19),
  suffixIcon: suffixIcon,
  filled: true,
  fillColor: const Color(0xFFFFFAF7),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFF0D9CE)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFFFA17E), width: 1.3),
  ),
);

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF654F44),
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _DottedBackdropPainter extends CustomPainter {
  const _DottedBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF2F4F4),
    );
    final dot = Paint()..color = const Color(0xFF929A9D).withValues(alpha: .35);
    for (double x = 8; x < size.width; x += 20) {
      for (double y = 8; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), .9, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBackdropPainter oldDelegate) => false;
}

class _PanelGridPainter extends CustomPainter {
  const _PanelGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFDBA997).withValues(alpha: .10)
      ..strokeWidth = .7;
    const gap = 30.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _PanelGridPainter oldDelegate) => false;
}
