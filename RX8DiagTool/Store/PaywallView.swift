import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Trial Status
                    if case .trial(let days) = subscriptionManager.subscriptionStatus {
                        trialBanner(daysRemaining: days)
                    } else if case .trialExpired = subscriptionManager.subscriptionStatus {
                        expiredBanner
                    }

                    // Features
                    featuresSection

                    // Products
                    productsSection

                    // Legal
                    legalSection
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("subscription.premium".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close".localized) {
                        dismiss()
                    }
                }
            }
        }
        .alert("common.error".localized, isPresented: $showError) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("paywall.title".localized)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("paywall.subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }

    // MARK: - Trial Banner

    private func trialBanner(daysRemaining: Int) -> some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(.orange)

            Text(String(format: "paywall.trial_remaining".localized, daysRemaining))
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.2))
        .cornerRadius(12)
    }

    private var expiredBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)

            Text("paywall.trial_expired_message".localized)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.2))
        .cornerRadius(12)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("paywall.features_title".localized)
                .font(.headline)
                .foregroundColor(.white)

            ForEach(PremiumFeature.allCases, id: \.self) { feature in
                FeatureRow(feature: feature)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }

    // MARK: - Products Section

    private var productsSection: some View {
        VStack(spacing: 12) {
            if subscriptionManager.isLoading {
                ProgressView()
                    .padding()
            } else if subscriptionManager.products.isEmpty {
                Text("paywall.products_unavailable".localized)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(subscriptionManager.products, id: \.id) { product in
                    ProductCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        isBestValue: product.id == ProductID.yearlyPremium.rawValue
                    ) {
                        selectedProduct = product
                    }
                }

                // Purchase Button
                if let product = selectedProduct {
                    Button(action: { Task { await purchase(product) } }) {
                        HStack {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("paywall.subscribe_button".localized)
                                Text("-")
                                Text(product.displayPrice)
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .disabled(isPurchasing)
                }

                // Restore Button
                Button(action: { Task { await restore() } }) {
                    Text("paywall.restore_purchases".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("paywall.legal_text".localized)
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            HStack(spacing: 20) {
                Link("paywall.privacy_policy".localized, destination: URL(string: "https://yourapp.com/privacy")!)
                    .font(.caption)
                    .foregroundColor(.blue)

                Link("paywall.terms".localized, destination: URL(string: "https://yourapp.com/terms")!)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.top)
    }

    // MARK: - Actions

    private func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            if let _ = try await subscriptionManager.purchase(product) {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func restore() async {
        await subscriptionManager.restorePurchases()

        if subscriptionManager.hasFullAccess {
            dismiss()
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let feature: PremiumFeature

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 30)

            Text(feature.title)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(productTitle)
                            .font(.headline)
                            .foregroundColor(.white)

                        if isBestValue {
                            Text("paywall.best_value".localized)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }

                    if let period = periodDescription {
                        Text(period)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if isBestValue, let savings = savingsText {
                        Text(savings)
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.orange.opacity(0.1) : Color.clear)
                    )
            )
        }
    }

    private var productTitle: String {
        switch product.id {
        case ProductID.monthlyPremium.rawValue:
            return "paywall.monthly_title".localized
        case ProductID.yearlyPremium.rawValue:
            return "paywall.yearly_title".localized
        case ProductID.lifetimePremium.rawValue:
            return "paywall.lifetime_title".localized
        default:
            return product.displayName
        }
    }

    private var periodDescription: String? {
        guard let subscription = product.subscription else {
            return "paywall.one_time_purchase".localized
        }

        switch subscription.subscriptionPeriod.unit {
        case .month:
            return "paywall.billed_monthly".localized
        case .year:
            return "paywall.billed_yearly".localized
        default:
            return nil
        }
    }

    private var savingsText: String? {
        // Calculate savings compared to monthly
        return "paywall.save_percent".localized
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
        .environmentObject(SubscriptionManager.shared)
}
