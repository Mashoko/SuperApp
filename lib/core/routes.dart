import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/features/home/presentation/views/home_view.dart';
import 'package:mvvm_sip_demo/features/auth/presentation/views/signup_view.dart';
import 'package:mvvm_sip_demo/features/profile/presentation/views/profile_view.dart';
import 'package:mvvm_sip_demo/features/calling/presentation/views/calling_view.dart';
import 'package:mvvm_sip_demo/features/calling/presentation/views/call_history_view.dart';
import 'package:mvvm_sip_demo/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/shopping_view.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/product_detail_view.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/cart_view.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/wishlist_view.dart';
import 'package:mvvm_sip_demo/features/utility_bills/presentation/views/utility_bills_view.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/checkout_view.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/order_completion_view.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/order_history_view.dart';
import 'package:mvvm_sip_demo/features/payments/presentation/views/payments_view.dart';
import 'package:mvvm_sip_demo/features/payments/presentation/views/service_providers_view.dart';
import 'package:mvvm_sip_demo/features/login/presentation/views/login_view.dart';
import 'package:mvvm_sip_demo/features/registration/presentation/views/registration_view.dart';

class Routes {
  static const String root = '/';
  static const String home = '/home'; // Maps to HomeView
  static const String dashboard = '/dashboard';
  static const String calling = '/calling';
  static const String callHistory = '/call-history';
  static const String shopping = '/shopping';
  static const String productDetails = '/shopping-product-details';
  static const String cart = '/shopping-cart';
  static const String wishlist = '/shopping-wishlist';

  static const String utilityBills = '/utility-bills';
  static const String checkout = '/shopping-checkout';
  static const String orderDetails = '/shopping-order-details';
  static const String orderHistory = '/shopping-order-history';
  static const String payments = '/payments';
  static const String serviceProviders = '/payments-service-providers';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String registration = '/registration';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes => {
        root: (context) => LoginView(),
        home: (context) => HomeView(),
        dashboard: (context) => DashboardView(),
        calling: (context) => CallingView(),
        callHistory: (context) => CallHistoryView(),
        shopping: (context) => ShoppingView(),
        productDetails: (context) => ProductDetailView(),
        cart: (context) => CartView(),
        wishlist: (context) => WishlistView(),

        utilityBills: (context) => UtilityBillsView(),
        checkout: (context) => CheckoutView(),
        orderDetails: (context) => OrderCompletionView(),
        orderHistory: (context) => OrderHistoryView(),
        payments: (context) => PaymentsView(),
        serviceProviders: (context) => ServiceProvidersView(),
        login: (context) => LoginView(),
        signup: (context) => SignupView(),
        profile: (context) => ProfileView(),
        registration: (context) => RegistrationView(),
      };
}

