import Foundation
import CustomAuth
import TorusUtils
let ClientID = "BPi5PB_UiIZ-cPz1GtV5i1I2iOSOHuimiXBI0e-Oe_u6X3oVAbCiAZOTEBtTXw4tsluTITPqA8zMsfxIKMjiqNQ"

class LoginModel: ObservableObject {
    @Published var loggedIn: Bool = false
    @Published var isLoading = false
    @Published var navigationTitle: String = ""
    @Published var userData: TorusKeyData!

    func setup() async {
        await MainActor.run(body: {
            isLoading = true
            navigationTitle = "Loading"
        })
        await MainActor.run(body: {
            if self.userData != nil {
                loggedIn = true
            }
            isLoading = false
            navigationTitle = loggedIn ? "UserInfo" : "SignIn"
        })
    }

    func loginWithCustomAuth() {

        Task {
            let verifier = "w3a-google-demo"
            let sub = SubVerifierDetails(loginType: .web,
                                         loginProvider: .google,
                                         clientId: "519228911939-cri01h55lsjbsia1k7ll6qpalrus75ps.apps.googleusercontent.com",
                                         verifier: verifier,
                                         redirectURL: "tdsdk://tdsdk/oauthCallback",
                                         browserRedirectURL: "https://scripts.toruswallet.io/redirect.html")
            let tdsdk = CustomAuth( web3AuthClientId: ClientID, aggregateVerifierType: .singleLogin, aggregateVerifier: verifier, subVerifierDetails: [sub], network: .sapphire(.SAPPHIRE_DEVNET), enableOneKey: true)
            do {
                let data = try await tdsdk.triggerLogin()

                await MainActor.run(body: {
                    self.userData = data
                    loggedIn = true
                })
            } catch {
                print(error)
            }

        }
    }

}
