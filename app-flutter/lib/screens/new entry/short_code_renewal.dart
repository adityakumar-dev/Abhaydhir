import 'package:flutter/material.dart';
import 'package:spring_admin/utils/constants/server_endpoints.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../apis/server_api.dart';

class ShortCodeRenewal extends StatefulWidget {
  final String? shortCode;

  const ShortCodeRenewal({
    Key? key,
    this.shortCode,
  }) : super(key: key);

  @override
  State<ShortCodeRenewal> createState() => _ShortCodeRenewalState();
}

class _ShortCodeRenewalState extends State<ShortCodeRenewal> {
  late TextEditingController _codeController;
  String? _selectedDate;
  bool _isLoading = false;
  final List<String> _availableDates = [  '2026-03-01'];
  final Map<String, String> _dateLabels = {
    
    '2026-03-01': 'Mar 1',
  };

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.shortCode ?? '');
    _selectedDate = _availableDates.first;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleRenewal() async {
    if (_codeController.text.isEmpty) {
      _showErrorDialog('Please enter your short code');
      return;
    }
    if (_selectedDate == null) {
      _showErrorDialog('Please select a date');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ServerApi.renewCard(
        shortCode: _codeController.text.trim(),
        validDate: _selectedDate!,
      );

      String? previewUrl;
      String? downloadUrl;
      try {
        final newShortCode = (result['new_short_code'] ?? '').toString().trim();
        if (newShortCode.isNotEmpty) {
          final cardData = await ServerApi.resolveShortCode(shortCode: newShortCode);
          final cardUrls = cardData['card_urls'] as Map<String, dynamic>?;
          String toFull(String p) =>
              p.startsWith('http') ? p : '${ServerEndpoints.baseUrl}$p';
          if (cardUrls?['preview'] != null) {
            previewUrl = toFull(cardUrls!['preview'] as String);
          }
          if (cardUrls?['download'] != null) {
            downloadUrl = toFull(cardUrls!['download'] as String);
          }
        }
      } catch (_) {}

      if (mounted) {
        _showSuccessDialog(result, previewUrl: previewUrl, downloadUrl: downloadUrl);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> result, {String? previewUrl, String? downloadUrl}) {
    final newShortCode = result['new_short_code'] ?? '';
    final newDate = result['new_date'] ?? _selectedDate;
    final name = result['name'] ?? 'Visitor';
    final outerContext = context;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Card Renewed!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'New Short Code',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    newShortCode,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Valid Date',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    newDate,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (previewUrl != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigator.pop(dialogContext);
                    Navigator.push(
                      outerContext,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(
                            backgroundColor: Colors.black,
                            iconTheme: const IconThemeData(color: Colors.white),
                            title: const Text(
                              'Card Preview',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          body: Center(
                            child: InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: Image.network(
                                previewUrl,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                          : null,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.broken_image,
                                          color: Colors.white, size: 48),
                                      SizedBox(height: 8),
                                      Text(
                                        'Failed to load card',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Preview Card'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            if (previewUrl != null) const SizedBox(height: 8),
            if (downloadUrl != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(downloadUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download Card'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            if (downloadUrl != null) const SizedBox(height: 8),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  // Navigator.pop(outerContext);
                  // Navigator.pop(outerContext); // Go back to home
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF00897B),
        elevation: 0,
        title: const Text('Quick Renewal', style: TextStyle(color: Colors.white)), 
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Short Code',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                hintText: 'Enter your short code (e.g., ABC123DEF456)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.qr_code_2),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),
            const Text(
              'Select New Valid Date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _availableDates.map((date) {
                final isSelected = _selectedDate == date;
                return ChoiceChip(
                  label: Text(_dateLabels[date] ?? date),
                  selected: isSelected,
                  onSelected: _isLoading
                      ? null
                      : (selected) {
                          if (selected) {
                            setState(() => _selectedDate = date);
                          }
                        },
                  selectedColor: const Color(0xFF00897B),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRenewal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Renew Card',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
