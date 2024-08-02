import Foundation
import CustomAuth
import TorusUtils

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

            let tdsdk = try CustomAuth(config: CustomAuthArgs(urlScheme: "tdsdk://tdsdk/oauthCallback", network: .sapphire(.SAPPHIRE_MAINNET), enableOneKey: true, web3AuthClientId: "Client ID"))

            let data = try await tdsdk.triggerLogin(args: SubVerifierDetails(typeOfLogin: .google, verifier: "google-lrc", clientId: "221898609709-obfn3p63741l5333093430j3qeiinaa8.apps.googleusercontent.com", redirectURL: "https://scripts.toruswallet.io/redirect.html"))

            await MainActor.run(body: {
                self.userData = data
                loggedIn = true
            })
        }
    }

}
