import CustomAuth
import Foundation
import FetchNodeDetails
import TorusUtils

let ClientID = "BPi5PB_UiIZ-cPz1GtV5i1I2iOSOHuimiXBI0e-Oe_u6X3oVAbCiAZOTEBtTXw4tsluTITPqA8zMsfxIKMjiqNQ"
let Network: TorusNetwork = .sapphire(.SAPPHIRE_MAINNET)
let verifier = "w3a-google-demo"

class LoginModel: ObservableObject {
    @Published var loggedIn: Bool = false
    @Published var isLoading = false
    @Published var navigationTitle: String = ""
    @Published var userData: TorusLoginResponse?

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
            do {
                let tdsdk = try CustomAuth(config: CustomAuthArgs(urlScheme: "tdsdk://tdsdk/oauthCallback", network: Network, enableOneKey: true, web3AuthClientId: ClientID))

                let data = try await tdsdk.triggerLogin(args: SubVerifierDetails(typeOfLogin: .google, verifier: verifier, clientId: "519228911939-cri01h55lsjbsia1k7ll6qpalrus75ps.apps.googleusercontent.com", redirectURL: "https://scripts.toruswallet.io/redirect.html"))

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
