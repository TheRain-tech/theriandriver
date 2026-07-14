import 'package:flutter/material.dart';

import '../config/env_config.dart';
import '../data/models/app_enums.dart';
import '../data/models/driver_vehicle.dart';
import '../features/auth/screens/biometric_lock_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/secure_access_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/startup_screen.dart';
import '../features/auth/screens/change_password_screen.dart';
import '../features/dashboard/screens/driver_dashboard_screen.dart';
import '../features/earnings/screens/earnings_dashboard_screen.dart';
import '../features/earnings/screens/earnings_summary_screen.dart';
import '../features/earnings/screens/payment_history_screen.dart';
import '../features/earnings/screens/payment_request_screen.dart';
import '../features/earnings/screens/revenue_history_screen.dart';
import '../features/fuel/screens/fuel_tracking_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/profile/screens/driver_profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/fleet_agreement_screen.dart';
import '../features/profile/screens/refer_and_earn_screen.dart';
import '../features/profile/screens/report_fleet_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/promotions/screens/promotions_screen.dart';
import '../features/rides/screens/go_to_pickup_screen.dart';
import '../features/rides/screens/new_ride_request_screen.dart';
import '../features/rides/screens/pickup_confirmed_screen.dart';
import '../features/rides/screens/trip_completed_screen.dart';
import '../features/rides/screens/trip_details_screen.dart';
import '../features/rides/screens/trip_in_progress_screen.dart';
import '../features/rides/screens/trips_history_screen.dart';
import '../features/subscription/screens/subscription_screen.dart';
import '../features/support/screens/contact_support_screen.dart';
import '../features/support/screens/emergency_screen.dart';
import '../features/support/screens/help_center_screen.dart';
import '../features/support/screens/report_issue_screen.dart';
import '../features/vehicle/screens/add_vehicle_screen.dart';
import '../features/vehicle/screens/vehicle_documents_screen.dart';
import '../features/vehicle/screens/vehicle_information_screen.dart';
import '../features/vehicle/screens/vehicle_management_screen.dart';
import '../features/verification/screens/affiliation_selection_screen.dart';
import '../features/verification/screens/driver_licence_verification_screen.dart';
import '../features/verification/screens/driver_profile_setup_screen.dart';
import '../features/verification/screens/fleet_join_screen.dart';
import '../features/verification/screens/live_selfie_verification_screen.dart';
import '../features/verification/screens/membership_pending_screen.dart';
import '../features/verification/screens/national_id_verification_screen.dart';
import '../features/verification/screens/region_selection_screen.dart';
import '../features/verification/screens/service_selection_screen.dart';
import '../features/verification/screens/vehicle_category_selection_screen.dart';
import '../features/verification/screens/verification_approved_screen.dart';
import '../features/verification/screens/verification_pending_screen.dart';
import '../features/verification/screens/verification_review_submit_screen.dart';
import '../features/verification/screens/account_suspended_screen.dart';
import '../features/verification/screens/submit_appeal_screen.dart';
import '../features/wallet/screens/wallet_screen.dart';
import '../features/wallet/screens/withdraw_screen.dart';
import '../features/wallet/screens/withdrawal_history_screen.dart';
import '../services/auth_service.dart';
import '../services/app_lock_service.dart';
import '../services/driver_profile_service.dart';
import '../services/driver_verification_service.dart';
import 'route_names.dart';

abstract final class AppRoutes {
  static final Set<String> _protectedRoutes = {
    RouteNames.dashboard,
    RouteNames.rideRequest,
    RouteNames.goToPickup,
    RouteNames.pickupConfirmed,
    RouteNames.tripInProgress,
    RouteNames.tripCompleted,
    RouteNames.trips,
    RouteNames.tripDetails,
    RouteNames.earnings,
    RouteNames.earningsSummary,
    RouteNames.revenueHistory,
    RouteNames.paymentRequest,
    RouteNames.paymentHistory,
    RouteNames.wallet,
    RouteNames.withdraw,
    RouteNames.withdrawalHistory,
    RouteNames.notifications,
    RouteNames.promotions,
    RouteNames.profile,
    RouteNames.editProfile,
    RouteNames.settings,
    RouteNames.referAndEarn,
    RouteNames.fleetAgreement,
    RouteNames.reportFleet,
    RouteNames.vehicles,
    RouteNames.addVehicle,
    RouteNames.vehicleDocuments,
    RouteNames.vehicleInformation,
    RouteNames.subscription,
    RouteNames.fuel,
  };

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings, {
    bool previewMode = false,
  }) {
    final requested = settings.name ?? RouteNames.onboarding;
    final name = _guard(requested, previewMode);
    final widget = _screenFor(name, settings.arguments);

    return MaterialPageRoute<dynamic>(
      settings: RouteSettings(name: name, arguments: settings.arguments),
      builder: (_) => widget,
    );
  }

  static String _guard(String requested, bool previewMode) {
    if (previewMode ||
        EnvConfig.previewMode ||
        !_protectedRoutes.contains(requested)) {
      return requested;
    }

    final uid = AuthService.instance.currentUserId;
    if (uid == null) {
      return RouteNames.login;
    }

    if (!AppLockService.instance.unlockedSession) {
      AppLockService.instance.setPendingRoute(requested);
      return RouteNames.appLock;
    }

    final profile = DriverProfileService.instance.profile.value;
    if (profile.isSuspended) {
      return RouteNames.suspended;
    }

    return switch (DriverVerificationService.instance.status) {
      DriverVerificationStatus.approved => requested,
      DriverVerificationStatus.pending => RouteNames.pending,
      DriverVerificationStatus.rejected ||
      DriverVerificationStatus.resubmissionRequired ||
      DriverVerificationStatus.notStarted ||
      DriverVerificationStatus.inProgress => RouteNames.profileSetup,
    };
  }

  static Widget _screenFor(String name, Object? arguments) => switch (name) {
    RouteNames.startup => const StartupScreen(),
    RouteNames.biometricLock => const BiometricLockScreen(),
    RouteNames.onboarding => const OnboardingScreen(),
    RouteNames.login => const LoginScreen(),
    RouteNames.signup => SignupScreen(),
    RouteNames.appLock => const SecureAccessScreen(),
    RouteNames.changePassword => const ChangePasswordScreen(),
    RouteNames.profileSetup => const DriverProfileSetupScreen(),
    RouteNames.affiliation => const AffiliationSelectionScreen(),
    RouteNames.region => const RegionSelectionScreen(),
    RouteNames.services => const ServiceSelectionScreen(),
    RouteNames.vehicleCategory => const VehicleCategorySelectionScreen(),
    RouteNames.fleetJoin => const FleetJoinScreen(),
    RouteNames.membershipPending => const MembershipPendingScreen(),
    RouteNames.nationalId => const NationalIdVerificationScreen(),
    RouteNames.licence => const DriverLicenceVerificationScreen(),
    RouteNames.selfie => const LiveSelfieVerificationScreen(),
    RouteNames.review => const VerificationReviewSubmitScreen(),
    RouteNames.pending => const VerificationPendingScreen(),
    RouteNames.approved => const VerificationApprovedScreen(),
    RouteNames.dashboard => DriverDashboardScreen(),
    RouteNames.rideRequest => NewRideRequestScreen(),
    RouteNames.goToPickup => GoToPickupScreen(),
    RouteNames.pickupConfirmed => PickupConfirmedScreen(),
    RouteNames.tripInProgress => TripInProgressScreen(),
    RouteNames.tripCompleted => const TripCompletedScreen(),
    RouteNames.trips => const TripsHistoryScreen(),
    RouteNames.tripDetails => TripDetailsScreen(tripId: arguments as String?),
    RouteNames.earnings => const EarningsDashboardScreen(),
    RouteNames.earningsSummary => EarningsSummaryScreen(),
    RouteNames.revenueHistory => const RevenueHistoryScreen(),
    RouteNames.paymentRequest => const PaymentRequestScreen(),
    RouteNames.paymentHistory => const PaymentHistoryScreen(),
    RouteNames.wallet => WalletScreen(),
    RouteNames.withdraw => const WithdrawScreen(),
    RouteNames.withdrawalHistory => const WithdrawalHistoryScreen(),
    RouteNames.notifications => NotificationsScreen(),
    RouteNames.promotions => PromotionsScreen(),
    RouteNames.helpCenter => const HelpCenterScreen(),
    RouteNames.contactSupport => const ContactSupportScreen(),
    RouteNames.reportIssue => const ReportIssueScreen(),
    RouteNames.emergency => const EmergencyScreen(),
    RouteNames.profile => const DriverProfileScreen(),
    RouteNames.editProfile => const EditProfileScreen(),
    RouteNames.settings => const SettingsScreen(),
    RouteNames.referAndEarn => const ReferAndEarnScreen(),
    RouteNames.fleetAgreement => const FleetAgreementScreen(),
    RouteNames.reportFleet => const ReportFleetScreen(),
    RouteNames.vehicles => VehicleManagementScreen(),
    RouteNames.addVehicle => const AddVehicleScreen(),
    RouteNames.vehicleDocuments => VehicleDocumentsScreen(),
    RouteNames.vehicleInformation => VehicleInformationScreen(
      vehicle: arguments as DriverVehicle?,
    ),
    RouteNames.subscription => SubscriptionScreen(),
    RouteNames.fuel => FuelTrackingScreen(),
    RouteNames.suspended => const AccountSuspendedScreen(),
    RouteNames.submitAppeal => const SubmitAppealScreen(),
    _ => const _NotFoundScreen(),
  };
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Page not found')),
    body: Center(
      child: FilledButton(
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.onboarding,
          (route) => false,
        ),
        child: const Text('Back to start'),
      ),
    ),
  );
}
