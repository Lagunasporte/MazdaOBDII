import Foundation
import StoreKit
import SwiftUI

// MARK: - Product IDs

enum ProductID: String, CaseIterable {
    case monthlyPremium = "com.renesismonitor.premium.monthly"
    case yearlyPremium = "com.renesismonitor.premium.yearly"
    case lifetimePremium = "com.renesismonitor.premium.lifetime"

    var isSubscription: Bool {
        switch self {
        case .monthlyPremium, .yearlyPremium:
            return true
        case .lifetimePremium:
            return false
        }
    }
}

// MARK: - Subscription Status

enum SubscriptionStatus: Equatable {
    case unknown
    case trial(daysRemaining: Int)
    case trialExpired
    case subscribed(expiryDate: Date?)
    case lifetime
    case notSubscribed

    var isActive: Bool {
        switch self {
        case .trial, .subscribed, .lifetime:
            return true
        case .unknown, .trialExpired, .notSubscribed:
            return false
        }
    }

    var displayText: String {
        switch self {
        case .unknown:
            return "subscription.status.unknown".localized
        case .trial(let days):
            return String(format: "subscription.trial_days_remaining".localized, days)
        case .trialExpired:
            return "subscription.trial_expired".localized
        case .subscribed(let date):
            if let date = date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return String(format: "subscription.active_until".localized, formatter.string(from: date))
            }
            return "subscription.active".localized
        case .lifetime:
            return "subscription.lifetime_active".localized
        case .notSubscribed:
            return "subscription.not_subscribed".localized
        }
    }
}

// MARK: - Subscription Manager

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // Trial configuration
    static let trialDurationDays = 14

    // Published properties
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .unknown
    @Published private(set) var isLoading = false
    @Published var showPaywall = false

    // Trial tracking
    @AppStorage("trialStartDate") private var trialStartDateString: String = ""
    @AppStorage("hasCompletedTrial") private var hasCompletedTrial: Bool = false

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        // Start listening for transactions
        updateListenerTask = listenForTransactions()

        // Load initial state
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
            initializeTrialIfNeeded()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Trial Management

    private var trialStartDate: Date? {
        get {
            guard !trialStartDateString.isEmpty else { return nil }
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: trialStartDateString)
        }
        set {
            if let date = newValue {
                let formatter = ISO8601DateFormatter()
                trialStartDateString = formatter.string(from: date)
            } else {
                trialStartDateString = ""
            }
        }
    }

    var trialDaysRemaining: Int {
        guard let startDate = trialStartDate else { return Self.trialDurationDays }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(0, Self.trialDurationDays - daysSinceStart)
    }

    var isTrialActive: Bool {
        return trialDaysRemaining > 0 && !hasCompletedTrial
    }

    var isTrialExpired: Bool {
        return trialStartDate != nil && trialDaysRemaining <= 0
    }

    private func initializeTrialIfNeeded() {
        if trialStartDate == nil && !hasCompletedTrial {
            trialStartDate = Date()
        }

        if isTrialExpired && !hasCompletedTrial {
            hasCompletedTrial = true
        }
    }

    func resetTrial() {
        // For testing only - remove in production
        #if DEBUG
        trialStartDateString = ""
        hasCompletedTrial = false
        Task {
            await updateSubscriptionStatus()
        }
        #endif
    }

    // MARK: - StoreKit 2 Integration

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
            products.sort { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    @MainActor
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        var hasLifetime = false
        var expiryDate: Date?

        // Check for entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchasedProductIDs.insert(transaction.productID)

                if transaction.productID == ProductID.lifetimePremium.rawValue {
                    hasLifetime = true
                } else if transaction.revocationDate == nil {
                    hasActiveSubscription = true
                    expiryDate = transaction.expirationDate
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        // Determine status
        if hasLifetime {
            subscriptionStatus = .lifetime
        } else if hasActiveSubscription {
            subscriptionStatus = .subscribed(expiryDate: expiryDate)
        } else if isTrialActive {
            subscriptionStatus = .trial(daysRemaining: trialDaysRemaining)
        } else if isTrialExpired {
            subscriptionStatus = .trialExpired
            showPaywall = true
        } else {
            subscriptionStatus = .notSubscribed
        }
    }

    // MARK: - Feature Access

    var hasFullAccess: Bool {
        return subscriptionStatus.isActive
    }

    func checkAccess() -> Bool {
        if !hasFullAccess {
            showPaywall = true
            return false
        }
        return true
    }

    // MARK: - Product Helpers

    func product(for id: ProductID) -> Product? {
        return products.first { $0.id == id.rawValue }
    }

    func priceString(for product: Product) -> String {
        return product.displayPrice
    }

    func periodString(for product: Product) -> String? {
        guard let subscription = product.subscription else { return nil }

        switch subscription.subscriptionPeriod.unit {
        case .month:
            return subscription.subscriptionPeriod.value == 1 ? "subscription.per_month".localized : "\(subscription.subscriptionPeriod.value) " + "subscription.months".localized
        case .year:
            return subscription.subscriptionPeriod.value == 1 ? "subscription.per_year".localized : "\(subscription.subscriptionPeriod.value) " + "subscription.years".localized
        case .week:
            return "subscription.per_week".localized
        case .day:
            return "subscription.per_day".localized
        @unknown default:
            return nil
        }
    }
}

// MARK: - Store Errors

enum StoreError: Error, LocalizedError {
    case verificationFailed
    case purchaseFailed
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "store.error.verification_failed".localized
        case .purchaseFailed:
            return "store.error.purchase_failed".localized
        case .productNotFound:
            return "store.error.product_not_found".localized
        }
    }
}

// MARK: - Premium Features

enum PremiumFeature: String, CaseIterable {
    case unlimitedDiagnostics = "premium.feature.unlimited_diagnostics"
    case aiAnalysis = "premium.feature.ai_analysis"
    case dataExport = "premium.feature.data_export"
    case blackboxRecording = "premium.feature.blackbox"
    case advancedAlerts = "premium.feature.advanced_alerts"
    case noAds = "premium.feature.no_ads"
    case prioritySupport = "premium.feature.priority_support"

    var icon: String {
        switch self {
        case .unlimitedDiagnostics: return "wrench.and.screwdriver.fill"
        case .aiAnalysis: return "brain"
        case .dataExport: return "square.and.arrow.up"
        case .blackboxRecording: return "recordingtape"
        case .advancedAlerts: return "bell.badge.fill"
        case .noAds: return "hand.raised.slash"
        case .prioritySupport: return "person.fill.questionmark"
        }
    }

    var title: String {
        return rawValue.localized
    }
}
