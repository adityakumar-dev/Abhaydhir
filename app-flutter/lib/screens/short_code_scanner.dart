import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:spring_admin/screens/view_card.dart';

class ShortCodeScannerScreen extends StatefulWidget {
  static const String routeName = '/short-code-scanner';

  const ShortCodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<ShortCodeScannerScreen> createState() => _ShortCodeScannerScreenState();
}

class _ShortCodeScannerScreenState extends State<ShortCodeScannerScreen> {
  final TextEditingController _codeController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = false;
  bool _hasScanned = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _openViewCard(String shortCode) {
    final trimmed = shortCode.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _error = 'Please enter a valid short code';
      });
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewCardScreen(shortCode: trimmed),
      ),
    );
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final rawValue = barcode.rawValue!;
    setState(() {
      _hasScanned = true;
    });
    _scannerController.stop();
    _openViewCard(rawValue);
  }

  void _resetScanner() {
    setState(() {
      _hasScanned = false;
      _error = null;
    });
    _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF00897B), Color(0xFF26A69A)],
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'View My Card',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top gradient header area
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 90, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Find Your Card',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter your short code or scan the QR on your card',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error banner
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Manual entry section
                  const Text(
                    'Enter Short Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Type your unique short code below',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.none,
                      decoration: InputDecoration(
                        hintText: 'e.g. a7b2c9',
                        hintStyle:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                        prefixIcon: const Icon(
                          Icons.code,
                          color: Color(0xFF00897B),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFF00897B),
                            size: 18,
                          ),
                          onPressed: () =>
                              _openViewCard(_codeController.text),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      onSubmitted: _openViewCard,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _openViewCard(_codeController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Find Card',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or scan QR code',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // QR Scanner section
                  const Text(
                    'Scan QR Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Point your camera at the QR code on your card',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  _isScanning
                      ? _buildScannerView()
                      : _buildScannerPreview(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerPreview() {
    return GestureDetector(
      onTap: () => setState(() => _isScanning = true),
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1A237E).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00897B).withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                color: Color(0xFF00897B),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tap to open camera',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00897B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan the QR code on your visitor card',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 300,
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onQrDetected,
            ),
          ),
        ),
        // Scanner overlay
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(
                painter: _ScannerOverlayPainter(),
              ),
            ),
          ),
        ),
        // Close button
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: () {
              _scannerController.stop();
              setState(() => _isScanning = false);
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
        if (_hasScanned)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'QR Scanned!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _resetScanner,
                      child: const Text(
                        'Scan Again',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    const scanSize = 180.0;
    final scanRect = Rect.fromCenter(
      center: center,
      width: scanSize,
      height: scanSize,
    );

    // Draw outer darken overlay with hole in centre
    final outerPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path()..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(12)));
    final combined = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(combined, paint);

    // Draw corner brackets
    final bracketPaint = Paint()
      ..color = const Color(0xFF00897B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const bracketLen = 24.0;
    final r = scanRect;
    // Top-left
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(bracketLen, 0), bracketPaint);
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(0, bracketLen), bracketPaint);
    // Top-right
    canvas.drawLine(r.topRight, r.topRight + const Offset(-bracketLen, 0), bracketPaint);
    canvas.drawLine(r.topRight, r.topRight + const Offset(0, bracketLen), bracketPaint);
    // Bottom-left
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(bracketLen, 0), bracketPaint);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(0, -bracketLen), bracketPaint);
    // Bottom-right
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(-bracketLen, 0), bracketPaint);
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(0, -bracketLen), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
