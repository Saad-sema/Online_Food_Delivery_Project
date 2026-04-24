import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ReviewScreen extends StatefulWidget {
  final int orderId;
  final String restaurantName;
  const ReviewScreen({super.key, required this.orderId, required this.restaurantName});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _restaurantRating = 5;
  int _deliveryRating = 5;
  final _commentController = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      // Submit restaurant review
      final res = await ApiService.postReview({
        'order_id': widget.orderId,
        'rating': _restaurantRating,
        'comment': _commentController.text,
        'review_for': 'restaurant',
      });

      if (res.data['success'] == true) {
        // Also submit delivery review
        await ApiService.postReview({
          'order_id': widget.orderId,
          'rating': _deliveryRating,
          'comment': '', // Optional
          'review_for': 'delivery_boy',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your review!'), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.data['message'] ?? 'Failed'), backgroundColor: Colors.red));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit review'), backgroundColor: Colors.red));
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Rate Your Order'), centerTitle: true, elevation: 0, backgroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.stars_rounded, size: 80, color: Color(0xFFFF6B35)),
            const SizedBox(height: 16),
            Text('How was your experience with ${widget.restaurantName}?', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            
            _ratingSection('Restaurant Rating', _restaurantRating, (v) => setState(() => _restaurantRating = v)),
            const SizedBox(height: 24),
            _ratingSection('Delivery Rating', _deliveryRating, (v) => setState(() => _deliveryRating = v)),
            
            const SizedBox(height: 32),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add a comment (optional)',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _submitting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingSection(String title, int current, Function(int) onSelect) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final star = i + 1;
            return IconButton(
              icon: Icon(star <= current ? Icons.star_rounded : Icons.star_outline_rounded, size: 40),
              color: star <= current ? const Color(0xFFFFB300) : Colors.grey.shade300,
              onPressed: () => onSelect(star),
            );
          }),
        ),
      ],
    );
  }
}
