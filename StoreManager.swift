import StoreKit

@MainActor
class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []

    func loadProducts() async {
        do {
            let productIds: Set<String> = ["com.yourapp.subscription.monthly", "com.yourapp.subscription.yearly"]
            let fetchedProducts = try await Product.products(for: productIds)
            
            DispatchQueue.main.async {
                self.products = fetchedProducts
            }
        } catch {
            print("❌ Error loading products: \(error.localizedDescription)")
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    print("✅ Purchase successful: \(transaction.productID)")
                    DispatchQueue.main.async {
                        self.purchasedSubscriptions.append(product)
                    }
                    await transaction.finish()
                case .unverified(_, let error):
                    print("❌ Unverified transaction: \(error.localizedDescription)")
                }
            case .pending:
                print("⏳ Purchase pending")
            case .userCancelled:
                print("❌ User cancelled purchase")
            @unknown default:
                print("❌ Unknown purchase state")
            }
        } catch {
            print("❌ Purchase failed: \(error.localizedDescription)")
        }
    }
}
