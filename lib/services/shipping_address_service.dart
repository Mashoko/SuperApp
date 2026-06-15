import 'dart:convert';
import 'package:http/http.dart' as http;

class ShippingAddress {
  final String id;
  final String userId;
  final String label;
  final String address;
  final String city;
  final String phone;
  final bool isDefault;

  const ShippingAddress({
    required this.id,
    required this.userId,
    required this.label,
    required this.address,
    this.city = '',
    this.phone = '',
    this.isDefault = false,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      id: json['_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class ShippingAddressService {
  static const String _base = 'https://superapp-diht.onrender.com/api';

  Future<List<ShippingAddress>> fetchAddresses(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_base/shipping-addresses?userId=${Uri.encodeComponent(userId)}'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => ShippingAddress.fromJson(j)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<ShippingAddress?> addAddress({
    required String userId,
    required String label,
    required String address,
    String city = '',
    String phone = '',
    bool isDefault = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/shipping-addresses'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'label': label,
          'address': address,
          'city': city,
          'phone': phone,
          'isDefault': isDefault,
        }),
      );
      if (response.statusCode == 201) {
        return ShippingAddress.fromJson(json.decode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteAddress(String id, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_base/shipping-addresses/$id?userId=${Uri.encodeComponent(userId)}'),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
