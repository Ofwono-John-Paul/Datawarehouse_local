import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../utils/replacement_video_preview_controller.dart';
import 'live_record_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _glossCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  PlatformFile? _selectedFile;
  bool _isLiveRecording = false;
  bool _hasConsent = false;
  bool _loading = false;
  bool _resolvingLocation = false;
  bool _districtLocked = false;

  double? _latitude;
  double? _longitude;
  String _geoSource = '';

  String _language = 'USL';
  String _sentenceType = 'Statement';
  String _category = 'Education';
  String _region = 'Central';

  static const _categories = ['Education', 'Health'];
  static const _regions = ['Central', 'Western', 'Eastern', 'Northern'];
  static const Map<String, List<String>> _sentenceTypesByCategory = {
    'Education': [
      'Statement',
      'Question',
      'Instruction',
      'Explanation',
      'Definition',
    ],
    'Health': ['Statement', 'Question', 'Advice', 'Warning', 'Instruction'],
  };

  List<String> get _sentenceTypes =>
      _sentenceTypesByCategory[_category] ?? const ['Statement'];

  @override
  void initState() {
    super.initState();
    _sentenceType = _sentenceTypes.first;
    _prefillSchoolLocation();
  }

  Future<void> _prefillSchoolLocation() async {
    final district = await ApiService.getSchoolDistrict();
    final region = await ApiService.getSchoolRegion();
    if (!mounted) return;
    setState(() {
      if (district.isNotEmpty) {
        _districtCtrl.text = district;
        _districtLocked = true;
      }
      if (region.isNotEmpty && _regions.contains(region)) {
        _region = region;
      }
    });
  }

  Future<void> _pickFile() async {
    // Use image_picker for web/mobile so picked files always have a previewable URI.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final picked = await _imagePicker.pickVideo(
          source: ImageSource.gallery,
        );
        if (picked == null || !mounted) return;

        final bytes = await picked.readAsBytes();
        if (!mounted) return;

        await _previewAndConfirmSelectedVideo(
          fileName: picked.name.isNotEmpty ? picked.name : 'selected_video.mp4',
          filePath: picked.path,
          bytes: bytes,
          isLiveSource: false,
        );
      } catch (_) {
        _showError('Could not open local video picker. Please try again.');
      }
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null || !mounted) return;

    final picked = result.files.first;
    await _previewAndConfirmSelectedVideo(
      fileName: picked.name,
      filePath: picked.path,
      bytes: picked.bytes,
      isLiveSource: false,
    );
  }

  Future<void> _recordLiveVideo() async {
    try {
      final captured = await Navigator.of(context).push<LiveVideoCaptureResult>(
        MaterialPageRoute(
          builder: (_) =>
              const LiveRecordScreen(maxDuration: Duration(minutes: 2)),
        ),
      );

      if (captured == null || !mounted) return;
      setState(() {
        _selectedFile = PlatformFile(
          name: captured.fileName,
          path: captured.filePath,
          size: captured.bytes.length,
          bytes: captured.bytes,
        );
        _isLiveRecording = true;
      });
    } catch (_) {
      _showError('Could not start camera recording on this device.');
    }
  }

  Future<void> _previewAndConfirmSelectedVideo({
    required String fileName,
    required bool isLiveSource,
    String? filePath,
    Uint8List? bytes,
  }) async {
    final controller = await createReplacementPreviewController(
      fileName: fileName,
      path: filePath,
      bytes: bytes,
    );

    if (controller == null) {
      _showError('Could not preview this video. Please pick another file.');
      return;
    }

    try {
      await controller.initialize();
      controller.setLooping(true);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      _showError(
        'Could not preview recorded video. Please try recording again.',
      );
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(isLiveSource ? 'Preview Recording' : 'Preview Video'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: controller.value.aspectRatio == 0
                        ? 16 / 9
                        : controller.value.aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: VideoPlayer(controller),
                    ),
                  ),
                  const SizedBox(height: 12),
                  IconButton(
                    iconSize: 34,
                    onPressed: () async {
                      if (controller.value.isPlaying) {
                        await controller.pause();
                      } else {
                        await controller.play();
                      }
                      setDialogState(() {});
                    },
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause_circle
                          : Icons.play_circle,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Reject'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.check),
                label: const Text('Accept'),
              ),
            ],
          ),
        );
      },
    );

    await controller.pause();
    await controller.dispose();

    if (accepted == true && mounted) {
      setState(() {
        _selectedFile = PlatformFile(
          name: fileName,
          path: filePath,
          size: bytes?.length ?? 0,
          bytes: bytes,
        );
        _isLiveRecording = isLiveSource;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _selectedFile = null;
        _isLiveRecording = false;
      });
    }
  }

  Future<bool> _confirmUploadConsent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Consent and Submit'),
        content: const Text(
          'You are about to submit this video. Please confirm that the signer '
          'has given consent and that this upload is permitted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _captureGeoTag() async {
    if (_resolvingLocation) return;
    setState(() => _resolvingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled on this device.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showError('Location permission denied. Geotag will be skipped.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _geoSource = 'device_gps';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location captured for this upload.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      _showError(
        'Could not capture location. You can still upload without geotag.',
      );
    } finally {
      if (mounted) setState(() => _resolvingLocation = false);
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or record a video file'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_hasConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide consent before uploading.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedFile!.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read file bytes. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await _confirmUploadConsent();
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      final res = await ApiService.uploadVideo(
        fileBytes: _selectedFile!.bytes,
        fileName: _selectedFile!.name,
        glossLabel: _glossCtrl.text.trim(),
        language: _language,
        sentenceType: _sentenceType,
        category: _category,
        region: _region,
        district: _districtCtrl.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        geoSource: _geoSource.isNotEmpty
            ? _geoSource
            : 'declared_region_district',
      );
      if (!mounted) return;
      if (res['statusCode'] == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
        Navigator.of(context).pop();
      } else {
        final errorMsg =
            res['body']['detail'] ?? res['body']['error'] ?? 'Upload failed';
        _showError(errorMsg.toString());
      }
    } catch (e) {
      _showError('Cannot reach server. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetForm() {
    _glossCtrl.clear();
    // Keep district/region if they were auto-filled from the school registration.
    if (!_districtLocked) {
      _districtCtrl.clear();
    }
    setState(() {
      _selectedFile = null;
      _isLiveRecording = false;
      _hasConsent = false;
      _latitude = null;
      _longitude = null;
      _geoSource = '';
      _category = 'Education';
      _language = 'USL';
      _sentenceType = _sentenceTypes.first;
      // Only reset region to default if it wasn't auto-filled.
      if (!_districtLocked) {
        _region = 'Central';
      }
    });
  }

  void _showError(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.upload_file, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Upload Sign Language Video',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Column(
                children: [
                  // ── Header banner ────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 660),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.sign_language,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contribute to the Dataset',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Upload a sign language video to help grow the USL corpus',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Form card ────────────────────────────────────────────
                  Form(
                    key: _formKey,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 660),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // section label
                          _sectionLabel('Sign Details', Icons.info_outline),
                          const SizedBox(height: 14),
                      // ── Gloss label ──────────────────────────────────────
                      TextFormField(
                        controller: _glossCtrl,
                        decoration: InputDecoration(
                          labelText: 'Gloss / Caption *',
                          hintText:
                              'Describe the sign and context (e.g. THANK YOU, used when expressing gratitude)',
                          prefixIcon: const Icon(Icons.sign_language),
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        minLines: 3,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),

                      // ── Dropdowns ────────────────────────────────────────
                      _dropdown(
                        'Topic of Interest *',
                        _category,
                        _categories,
                        Icons.category,
                        (v) {
                          final nextCategory = v ?? _category;
                          setState(() {
                            _category = nextCategory;
                            if (!_sentenceTypes.contains(_sentenceType)) {
                              _sentenceType = _sentenceTypes.first;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.shade50,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.language, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Language / Variant',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'USL',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                          const SizedBox(height: 14),
                          _dropdown(
                            'Sentence Type',
                            _sentenceType,
                            _sentenceTypes,
                            Icons.type_specimen,
                            (v) => setState(() => _sentenceType = v!),
                          ),
                          const SizedBox(height: 24),
                          _sectionLabel('Location', Icons.location_on_outlined),
                          const SizedBox(height: 14),
                          _districtLocked
                          ? _lockedField('Region', _region, Icons.map_outlined)
                          : _dropdown(
                              'Region',
                              _region,
                              _regions,
                              Icons.map_outlined,
                              (v) => setState(() => _region = v!),
                            ),
                      const SizedBox(height: 14),

                      // ── District ─────────────────────────────────────────
                      TextFormField(
                        controller: _districtCtrl,
                        readOnly: _districtLocked,
                        decoration: InputDecoration(
                          labelText: 'District',
                          prefixIcon: const Icon(Icons.location_city),
                          suffixIcon: _districtLocked
                              ? const Tooltip(
                                  message: 'Auto-filled from your school registration',
                                  child: Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: _districtLocked,
                          fillColor: _districtLocked ? Colors.grey.shade100 : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                          // ── Geotag capture ─────────────────────────────
                          OutlinedButton.icon(
                            onPressed: (_loading || _resolvingLocation)
                                ? null
                                : _captureGeoTag,
                            icon: _resolvingLocation
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location),
                            label: Text(
                              _latitude == null || _longitude == null
                                  ? 'Capture Current Location'
                                  : 'Refresh Location',
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 44),
                              side: BorderSide(
                                  color: _latitude != null
                                      ? Colors.green
                                      : Colors.grey.shade400),
                              foregroundColor:
                                  _latitude != null ? Colors.green : null,
                            ),
                          ),
                          if (_latitude != null && _longitude != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.green.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        size: 16,
                                        color: Colors.green.shade600),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Geotag captured: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                                        style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Optional — upload can proceed without location.',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 24),
                          _sectionLabel('Video File', Icons.video_file_outlined),
                          const SizedBox(height: 14),

                          // ── File picker box ────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedFile != null
                                ? Colors.green
                                : Colors.grey[300]!,
                            width: _selectedFile != null ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: _selectedFile != null
                              ? Colors.green.withValues(alpha: 0.05)
                              : null,
                        ),
                        child: _selectedFile == null
                            ? Column(
                                children: [
                                  Icon(
                                    Icons.video_file,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No video selected',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _pickFile,
                                        icon: const Icon(Icons.folder_open),
                                        label: const Text('Local Video'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: cs.primary,
                                          foregroundColor: cs.onPrimary,
                                        ),
                                      ),
                                      FilledButton.icon(
                                        onPressed: _recordLiveVideo,
                                        icon: const Icon(Icons.videocam),
                                        label: const Text('Live Recording'),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 48,
                                    color: Colors.green[500],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _selectedFile!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Chip(
                                    avatar: Icon(
                                      _isLiveRecording
                                          ? Icons.videocam
                                          : Icons.folder,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _isLiveRecording
                                          ? 'Live recording selected'
                                          : 'Local video selected',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextButton.icon(
                                    onPressed: _pickFile,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Change File'),
                                  ),
                                ],
                              ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: _hasConsent
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _hasConsent
                                    ? Colors.blue.shade200
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: CheckboxListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                              value: _hasConsent,
                              onChanged: _loading
                                  ? null
                                  : (value) => setState(
                                      () => _hasConsent = value ?? false),
                              title: const Text(
                                'I confirm informed consent was obtained.',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                              subtitle: const Text(
                                'Required before upload submission.',
                                style: TextStyle(fontSize: 12),
                              ),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              activeColor: Colors.blue.shade600,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Upload button ─────────────────────────────────
                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _upload,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.cloud_upload, size: 22),
                                        SizedBox(width: 10),
                                        Text(
                                          'Submit Upload',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.4),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1565C0),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFF1565C0).withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    IconData icon,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _lockedField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade100,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Auto-filled from your school registration',
            child: Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
