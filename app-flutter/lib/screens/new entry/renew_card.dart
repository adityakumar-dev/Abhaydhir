import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'short_code_renewal.dart';
import 'phone_renewal.dart';

class RenewCard extends StatefulWidget {
  final String? shortCode;
  final String? initialError;

  const RenewCard({
    Key? key,
    this.shortCode,
    this.initialError,
  }) : super(key: key);

  @override
  State<RenewCard> createState() => _RenewCardState();
}

class _RenewCardState extends State<RenewCard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00897B), Color(0xFF26A69A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: AppBar(
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Renew Card',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error message if exists
                    if (widget.initialError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[700],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.initialError!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Header
                    const Text(
                      'Choose Renewal Method',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select how you want to renew your card',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Quick Renewal Card
                    _buildMethodCard(
                      context,
                      icon: Icons.code,
                      iconBgColor: Colors.blue,
                      title: 'Quick Renewal',
                      subtitle: 'Use Short Code',
                      description: 'Fast renewal using your short code',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ShortCodeRenewal(
                              shortCode: widget.shortCode,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Phone Renewal Card
                    _buildMethodCard(
                      context,
                      icon: Icons.phone_in_talk,
                      iconBgColor: Colors.green,
                      title: 'Phone Renewal',
                      subtitle: 'Use Phone Number',
                      description: 'Renew using your registered phone',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PhoneRenewal(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // QR Scan Renewal Card
                    _buildMethodCard(
                      context,
                      icon: Icons.qr_code_scanner,
                      iconBgColor: Colors.deepPurple,
                      title: 'QR Scan Renewal',
                      subtitle: 'Scan Your QR Code',
                      description: 'Scan the QR on your visitor card to renew',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const _QrRenewalScannerScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildMethodCard(
    BuildContext context, {
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String description,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: iconBgColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconBgColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// QR Renewal Scanner – scans a QR and opens ShortCodeRenewal with the result
// ─────────────────────────────────────────────────────────────────────────────

class _QrRenewalScannerScreen extends StatefulWidget {
  const _QrRenewalScannerScreen();

  @override
  State<_QrRenewalScannerScreen> createState() =>
      _QrRenewalScannerScreenState();
}

class _QrRenewalScannerScreenState extends State<_QrRenewalScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() => _detected = true);
    _controller.stop();

    // Replace scanner with ShortCodeRenewal so Back returns to RenewCard
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ShortCodeRenewal(shortCode: rawValue.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan QR to Renew',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Toggle torch',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Full-screen camera
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Dark overlay with scan window
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ScanOverlayPainter(),
          ),
          // Instruction label
          Align(
            alignment: const Alignment(0, 0.72),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Point camera at the QR code on your card',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a semi-transparent overlay with a clear square scan window.
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double windowSize = 260;
    final double left = (size.width - windowSize) / 2;
    final double top = (size.height - windowSize) / 2 - 40;
    final Rect window = Rect.fromLTWH(left, top, windowSize, windowSize);

    final Paint dark = Paint()..color = Colors.black.withOpacity(0.55);
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dark);

    // Corner brackets
    final Paint bracket = Paint()
      ..color = const Color(0xFF00897B)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const double bLen = 24;
    final r = window;
    // TL
    canvas.drawLine(Offset(r.left, r.top + bLen), Offset(r.left, r.top), bracket);
    canvas.drawLine(Offset(r.left, r.top), Offset(r.left + bLen, r.top), bracket);
    // TR
    canvas.drawLine(Offset(r.right - bLen, r.top), Offset(r.right, r.top), bracket);
    canvas.drawLine(Offset(r.right, r.top), Offset(r.right, r.top + bLen), bracket);
    // BL
    canvas.drawLine(Offset(r.left, r.bottom - bLen), Offset(r.left, r.bottom), bracket);
    canvas.drawLine(Offset(r.left, r.bottom), Offset(r.left + bLen, r.bottom), bracket);
    // BR
    canvas.drawLine(Offset(r.right - bLen, r.bottom), Offset(r.right, r.bottom), bracket);
    canvas.drawLine(Offset(r.right, r.bottom), Offset(r.right, r.bottom - bLen), bracket);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}