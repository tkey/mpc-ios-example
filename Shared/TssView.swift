import BigInt
import CommonSources
import CryptoKit
import FetchNodeDetails
import Foundation
import SwiftUI
import tkey_pkg
import TorusUtils
import tss_client_swift
import Web3SwiftMpcProvider
import web3

struct TssView: View {
    @Binding var threshold_key: ThresholdKey!
    @Binding var verifier: String!
    @Binding var verifierId: String!
    @Binding var signatures: [[String: Any]]!
    @Binding var tssEndpoints: [String]!
    @Binding var showTss: Bool
    @Binding var nodeDetails: AllNodeDetailsModel?
    @Binding var torusUtils: TorusUtils?
    @Binding var metadataPublicKey: String
    @Binding var deviceFactorPub: String

    @State var showAlert: Bool = false
    @State private var selected_tag: String = ""
    @State private var alertContent = ""

    @State var clientIndex: Int32?
    @State var partyIndexes: [Int?] = []
    @State var session: String?
    @State var publicKey: Data?
    @State var share: BigInt?
    @State var socketUrls: [String?] = []
    @State var urls: [String?] = []
    @State var sigs: [String] = []
    @State var coeffs: [String: String] = [:]
    @State var signingData = false
    @State var sigHex = false
    @State var allFactorPub: [String] = []
    @State var tss_pub_key: String = ""

    @State var showSpinner = false

    @State var selectedFactorPub: String

    func updateTag ( key: String) {
        Task {
            selected_tag = key
            tss_pub_key = try await TssModule.get_tss_pub_key(threshold_key: threshold_key, tss_tag: selected_tag)
            allFactorPub = try await TssModule.get_all_factor_pub(threshold_key: threshold_key, tss_tag: selected_tag)
            print(allFactorPub)
            signingData = true
        }
    }

    var body: some View {
        Section(header: Text("TSS Example")) {
            Button(action: {
                Task {
                    showTss = false
                }
            }) { Text("Home") }
        }.onAppear {
            updateTag(key: "default")
        }

        /// Section on example of using different tagged tss key
//        Section(header: Text("Tss Module")) {
//            HStack {
//                Button(action: {
//                    // show input popup
//                    let alert = UIAlertController(title: "Enter New Tss Tag", message: nil, preferredStyle: .alert)
//                    alert.addTextField { textField in
//                        textField.placeholder = "New Tag"
//                    }
//                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
//                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] _ in
//                        guard let textField = alert?.textFields?.first else { return }
//                        Task {
//                            let tag = textField.text ?? "default"
//                            let saveId = tag + ":0"
//                            // generate factor key
//                            let factorKey = try PrivateKey.generate()
//                            // derive factor pub
//                            let factorPub = try factorKey.toPublic()
//                            // use input to create tag tss share
//                            do {
//                                print(try threshold_key.get_all_tss_tags())
//                                try await TssModule.create_tagged_tss_share(threshold_key: self.threshold_key, tss_tag: tag, deviceTssShare: nil, factorPub: factorPub, deviceTssIndex: 2, nodeDetails: self.nodeDetails!, torusUtils: self.torusUtils!)
//                                // set factor key into keychain
//                                try KeychainInterface.save(item: factorKey.hex, key: saveId)
//                                alertContent = factorKey.hex
//                            } catch {
//                                print("error tss")
//                            }
//                        }
//                    }))
//
//                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
//                        windowScene.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
//                    }
//                }) { Text("create new tagged tss") }
//            }
//        }.alert(isPresented: $showAlert) {
//            Alert(title: Text("Alert"), message: Text(alertContent), dismissButton: .default(Text("Ok")))
//        }

//        let tss_tags = try! threshold_key.get_all_tss_tags()

//        if !tss_tags.isEmpty {
//            Section(header: Text("TSS Tag")) {
//                ForEach(tss_tags, id: \.self) { key in
//                    HStack {
//                        Button(action: {
//                            Task {
//                                selected_tag = key
//                                tss_pub_key = try await TssModule.get_tss_pub_key(threshold_key: threshold_key, tss_tag: selected_tag)
//                                allFactorPub = try await TssModule.get_all_factor_pub(threshold_key: threshold_key, tss_tag: selected_tag)
//                                print(allFactorPub)
//                                signingData = true
//                            }
//                        }) { Text(key) }
//                    }
//                }
//            }
//        }

        if tss_pub_key != "" {
            Text("Tss public key for " + selected_tag)
            Text(tss_pub_key)

            Section(header: Text("Tss : " + selected_tag + " : Factors")) {
                ForEach(Array(allFactorPub), id: \.self) { factorPub in
                    Text(factorPub)
                }
            }
        }

        if !selected_tag.isEmpty {
            Section(header: Text("TSS : " + selected_tag)) {
                HStack {
                    if showSpinner {
                        LoaderView()
                    }
                    Button(action: {

                        Task {
                            do {
                                showSpinner = true
                                // generate factor key if input is empty
                                // derive factor pub
                                let newFactorKey = try PrivateKey.generate()
                                let newFactorPub = try newFactorKey.toPublic()

                                // use exising factor to generate tss share with index 3 with new factor
                                let factorKey = try KeychainInterface.fetch(key: selectedFactorPub)

                                let shareIndex = try await TssModule.find_device_share_index(threshold_key: threshold_key, factor_key: factorKey)
                                try TssModule.backup_share_with_factor_key(threshold_key: threshold_key, shareIndex: shareIndex, factorKey: newFactorKey.hex)

                                // for now only tss index 2 and index 3 are supported
                                let tssShareIndex = Int32(3)
                                let sigs: [String] = try signatures.map { String(decoding: try JSONSerialization.data(withJSONObject: $0), as: UTF8.self) }
                                try await TssModule.add_factor_pub(threshold_key: threshold_key, tss_tag: selected_tag, factor_key: factorKey, auth_signatures: sigs, new_factor_pub: newFactorPub, new_tss_index: tssShareIndex, nodeDetails: nodeDetails!, torusUtils: torusUtils!)

                                let saveNewFactorId = newFactorPub
                                try KeychainInterface.save(item: newFactorKey.hex, key: saveNewFactorId)

                                let description = [
                                    "module": "Manual Backup",
                                    "tssTag": selected_tag,
                                    "tssShareIndex": tssShareIndex,
                                    "dateAdded": Date().timeIntervalSince1970
                                ] as [String: Codable]
                                let jsonStr = try factorDescription(dataObj: description)
                                try await threshold_key.add_share_description(key: newFactorPub, description: jsonStr)
                                // show factor key used

                                let mnemonic = try ShareSerializationModule.serialize_share(threshold_key: threshold_key, share: newFactorKey.hex, format: "mnemonic")
                                // copy to paste board on success generated factor
                                UIPasteboard.general.string = mnemonic

                                let (newTssIndex, newTssShare) = try await TssModule.get_tss_share(threshold_key: threshold_key, tss_tag: selected_tag, factorKey: newFactorKey.hex)
                                updateTag(key: selected_tag)
                                alertContent = "tssIndex:" + newTssIndex + "\n" + "tssShare:" + newTssShare + "\n" + "newFactorKey" + newFactorKey.hex  + mnemonic
                                showAlert = true
                                showSpinner = false
                            } catch {
                                alertContent = "Invalid Factor Key"
                                showAlert = true
                                showSpinner = false
                            }
                        }
                    }) { Text("Create New TSSShare Into Manual Backup Factor") }
                }.alert(isPresented: $showAlert) {
                    Alert(title: Text("Alert"), message: Text(alertContent), dismissButton: .default(Text("Ok")))
                }.disabled(showSpinner )
                    .opacity(showSpinner ? 0.5 : 1)

                HStack {
                    if showSpinner {
                        LoaderView()
                    }
                    Button(action: {
                        Task {
                            showSpinner = true
                            // generate factor key if input is empty
                            // derive factor pub
                            let newFactorKey = try PrivateKey.generate()
                            let newFactorPub = try convertPublicKeyFormat(publicKey: newFactorKey.toPublic(), outFormat: .EllipticCompress)

                            // get existing factor key
                            let factorKey = try KeychainInterface.fetch(key: selectedFactorPub)

                            let shareIndex = try await TssModule.find_device_share_index(threshold_key: threshold_key, factor_key: factorKey)
                            try TssModule.backup_share_with_factor_key(threshold_key: threshold_key, shareIndex: shareIndex, factorKey: newFactorKey.hex)

                            let (tssShareIndex, _ ) = try await TssModule.get_tss_share(threshold_key: threshold_key, tss_tag: selected_tag, factorKey: factorKey)

                            // tssShareIndex provided will be cross checked with factorKey to prevent wrong tss share copied
                            try await TssModule.copy_factor_pub(threshold_key: threshold_key, tss_tag: selected_tag, factorKey: factorKey, newFactorPub: newFactorPub, tss_index: Int32(tssShareIndex)!)

                            let saveNewFactorId = newFactorPub
                            try KeychainInterface.save(item: newFactorKey.hex, key: saveNewFactorId)
                            // show factor key used
                            let description = [
                                "module": "Manual Backup",
                                "tssTag": selected_tag,
                                "tssShareIndex": tssShareIndex,
                                "dateAdded": Date().timeIntervalSince1970
                            ] as [String: Codable]
                            let jsonStr = try factorDescription(dataObj: description)
                            try await threshold_key.add_share_description(key: newFactorPub, description: jsonStr)

                            let mnemonic = try ShareSerializationModule.serialize_share(threshold_key: threshold_key, share: newFactorKey.hex, format: "mnemonic")

                            // copy to paste board on success generated factor
                            UIPasteboard.general.string = mnemonic

                            let (newTssIndex, newTssShare) = try await TssModule.get_tss_share(threshold_key: threshold_key, tss_tag: selected_tag, factorKey: newFactorKey.hex)
                            updateTag(key: selected_tag)
                            alertContent = "tssIndex:" + newTssIndex + "\n" + "tssShare:" + newTssShare + "\n" + "newFactorKey" + newFactorKey.hex  + mnemonic
                            showAlert = true
                            showSpinner = false
                        }
                    }) { Text("Copy Existing TSS Share For New Factor Manual") }
                }.alert(isPresented: $showAlert) {
                    Alert(title: Text("Alert"), message: Text(alertContent), dismissButton: .default(Text("Ok")))
                }.disabled(showSpinner )
                    .opacity(showSpinner ? 0.5 : 1)

                HStack {
                    if showSpinner {
                        LoaderView()
                    }
                    Button(action: {
                        Task {
                            // get factor key from keychain if input is empty

                            showSpinner = true
                            var deleteFactorKey: String?
                            var deleteFactor: String?
                            do {
                                let allFactorPub = try await TssModule.get_all_factor_pub(threshold_key: threshold_key, tss_tag: selected_tag)
                                print(allFactorPub)
                                // filterout device factor
                                let filterFactorPub = allFactorPub.filter({ $0 != deviceFactorPub })
                                print(filterFactorPub)

                                deleteFactor = filterFactorPub[0]

                                deleteFactorKey = try KeychainInterface.fetch(key: deleteFactor!)
                                if deleteFactorKey == "" {
                                    throw RuntimeError("")
                                }
                            } catch {
                                alertContent = "There is no extra factor key to be deleted"
                                showAlert = true
                                return
                            }
                            guard let deleteFactorKey = deleteFactorKey else {
                                alertContent = "There is no extra factor key to be deleted"
                                showAlert = true
                                return
                            }

                            // delete factor pub
                            let deleteFactorPK = PrivateKey(hex: deleteFactorKey)

                            let saveId = deviceFactorPub

                            let factorKey = try KeychainInterface.fetch(key: saveId)
                            let sigs: [String] = try signatures.map { String(decoding: try JSONSerialization.data(withJSONObject: $0), as: UTF8.self) }
                            try await TssModule.delete_factor_pub(threshold_key: threshold_key, tss_tag: selected_tag, factor_key: factorKey, auth_signatures: sigs, delete_factor_pub: deleteFactorPK.toPublic(), nodeDetails: nodeDetails!, torusUtils: torusUtils!)
                            print("done delete factor pub")
                            try KeychainInterface.save(item: "", key: deleteFactor!)
                            updateTag(key: selected_tag)
                            alertContent = "deleted factor key :" + deleteFactorKey
                            showAlert = true
                            showSpinner = false
                        }
                    }) { Text("Delete Most Recent Factor") }
                }.alert(isPresented: $showAlert) {
                    Alert(title: Text("Alert"), message: Text(alertContent), dismissButton: .default(Text("Ok")))
                }.disabled(showSpinner )
                    .opacity(showSpinner ? 0.5 : 1)
            }

            HStack {
                if showSpinner {
                    LoaderView()
                }
                Button(action: {
                    Task {
                        var deleteFactorKey: String = ""
                        do {
                            showSpinner = true
                            deleteFactorKey = try KeychainInterface.fetch(key: deviceFactorPub)
                            if deleteFactorKey == "" {
                                throw RuntimeError("Key was deleted")
                            }
                        } catch {
                            alertContent = "factor was deleted"
                            showAlert = true
                            showSpinner = false
                        }
                        do {
                            let sigs: [String] = try signatures.map { String(decoding: try JSONSerialization.data(withJSONObject: $0), as: UTF8.self) }
                            try await TssModule.delete_factor_pub(threshold_key: threshold_key, tss_tag: selected_tag, factor_key: deleteFactorKey, auth_signatures: sigs, delete_factor_pub: deviceFactorPub, nodeDetails: nodeDetails!, torusUtils: torusUtils!)
                            try KeychainInterface.save(item: "", key: deviceFactorPub)
                            try KeychainInterface.save(item: "", key: metadataPublicKey)

                            print("done delete factor pub")
                            updateTag(key: selected_tag)
                            alertContent = "deleted factor key :" + deleteFactorKey
                            showAlert = true
                            showSpinner = false
                        } catch {
                            alertContent = "unable to delete factor. Possible wrong factor key"
                            showAlert = true
                            showSpinner = false
                        }

                    }
                }) { Text("Delete Device Factor") }
                    .disabled( !signingData )
                    .disabled(showSpinner )
                    .opacity(showSpinner ? 0.5 : 1)
            }

            HStack {
                if showSpinner {
                    LoaderView()
                }

                Button(action: {
                    Task {
                        showSpinner = true
                        do {
                            let sigs: [String] = try signatures.map { String(decoding: try JSONSerialization.data(withJSONObject: $0), as: UTF8.self) }
                            // get the factor key information

                            let factorKey = try KeychainInterface.fetch(key: selectedFactorPub)
                            // Create tss Client using helper

                            // verify the signature
                            let publicKey = try await TssModule.get_tss_pub_key(threshold_key: threshold_key, tss_tag: selected_tag)
                            let (tssIndex, tssShare) = try await TssModule.get_tss_share(threshold_key: threshold_key, tss_tag: selected_tag, factorKey: factorKey)
                            let tssNonce = try TssModule.get_tss_nonce(threshold_key: threshold_key, tss_tag: selected_tag)

                            let keypoint = try KeyPoint(address: publicKey)
                            let fullAddress = try "04" + keypoint.getX() + keypoint.getY()

                            let params = EthTssAccountParams(publicKey: fullAddress, factorKey: factorKey, tssNonce: tssNonce, tssShare: tssShare, tssIndex: tssIndex, selectedTag: selected_tag, verifier: verifier, verifierID: verifierId, nodeIndexes: [], tssEndpoints: tssEndpoints, authSigs: sigs)

                            let account = try EthereumTssAccount(params: params)

                            let msg = "hello world"
                            let msgHash = msg.data(using: .utf8)?.sha3(.keccak256)
                            let signature = try account.sign(message: msg)
                            print(signature)
                            print(signature.toHexString())
                            let r = BigInt( sign: .plus, magnitude: BigUInt(signature.prefix(32)))
                            let s = BigInt( sign: .plus, magnitude: BigUInt(signature.prefix(64).suffix(32)))
                            let v = UInt8(signature.suffix(1).toHexString(), radix: 16 )! + 27

                            print(try TSSHelpers.hexSignature(s: s, r: r, v: v))
                            if TSSHelpers.verifySignature(msgHash: msgHash!.toHexString(), s: s, r: r, v: v, pubKey: Data(hex: fullAddress)) {
                               let sigHex = try TSSHelpers.hexSignature(s: s, r: r, v: v)
                               alertContent = "Signature: " + sigHex
                               showAlert = true
                               print(try TSSHelpers.hexSignature(s: s, r: r, v: v))
                            } else {
                               alertContent = "Signature could not be verified"
                               showAlert = true
                            }
                        } catch {
                            alertContent = "Signing could not be completed. please try again"
                            showAlert = true
                        }
                        showSpinner = false
                    }
                }) { Text("Sign Message") }
                    .disabled( !signingData )
                    .disabled(showSpinner )
                    .opacity(showSpinner ? 0.5 : 1)

            }
            HStack {
                if showSpinner {
                    LoaderView()
                }
                Button(action: {
                    Task {
                        do {
                            let selected_tag = try TssModule.get_tss_tag(threshold_key: threshold_key)

                            let factorKey = try KeychainInterface.fetch(key: selectedFactorPub)

                            let (tssIndex, tssShare) = try await TssModule.get_tss_share(threshold_key: threshold_key, tss_tag: selected_tag, factorKey: factorKey)

                            let tssNonce = try TssModule.get_tss_nonce(threshold_key: threshold_key, tss_tag: selected_tag)

                            let tssPublicAddressInfo = try await TssModule.get_dkg_pub_key(threshold_key: threshold_key, tssTag: selected_tag, nonce: String(tssNonce), nodeDetails: nodeDetails!, torusUtils: torusUtils!)

                            let finalPubKey = try await TssModule.get_tss_pub_key(threshold_key: threshold_key, tss_tag: selected_tag)

                            let tssPubKeyPoint = try KeyPoint(address: finalPubKey)
                            let fullTssPubKey = try tssPubKeyPoint.getPublicKey(format: PublicKeyEncoding.FullAddress)

                            let evmAddress = KeyUtil.generateAddress(from: Data(hex: fullTssPubKey).suffix(64) )
                            print(evmAddress.toChecksumAddress())

                            // step 2. getting signature
                            let sigs: [String] = try signatures.map { String(decoding: try JSONSerialization.data(withJSONObject: $0), as: UTF8.self) }

                            let params = EthTssAccountParams(publicKey: fullTssPubKey, factorKey: factorKey, tssNonce: tssNonce, tssShare: tssShare, tssIndex: tssIndex, selectedTag: selected_tag, verifier: verifier, verifierID: verifierId, nodeIndexes: tssPublicAddressInfo.nodeIndexes, tssEndpoints: tssEndpoints, authSigs: sigs)

                            let tssAccount = try EthereumTssAccount(params: params)

                            let RPC_URL = "https://api.avax-test.network/ext/bc/C/rpc"
                            let chainID = 43113
                            //                    let RPC_URL = "https://rpc.ankr.com/eth_goerli"
                            //                    let chainID = 5
                            let web3Client = EthereumHttpClient(url: URL(string: RPC_URL)!)

                            let amount = 0.001
                            let toAddress = tssAccount.address
                            let fromAddress = tssAccount.address
                            let gasPrice = try await web3Client.eth_gasPrice()
                            let maxTipInGwie = BigUInt(TorusWeb3Utils.toEther(gwei: BigUInt(amount)))
                            let totalGas = gasPrice + maxTipInGwie
                            let gasLimit = BigUInt(21000)

                            let amtInGwie = TorusWeb3Utils.toWei(ether: amount)
                            let nonce = try await web3Client.eth_getTransactionCount(address: fromAddress, block: .Latest)
                            let transaction = EthereumTransaction(from: fromAddress, to: toAddress, value: amtInGwie, data: Data(), nonce: nonce + 1, gasPrice: totalGas, gasLimit: gasLimit, chainId: chainID)
                            // let signed = try tssAccount.sign(transaction: transaction)
                            let val = try await web3Client.eth_sendRawTransaction(transaction, withAccount: tssAccount)
                            alertContent = "transaction sent"
                            // alertContent = "transaction signature: " + //(signed.hash?.toHexString() ?? "")
                            showAlert = true
                        } catch {
                            alertContent = "Signing could not be completed. please try again"
                            showAlert = true
                        }
                    }
                }) { Text("transaction signing: send eth") }
                    .disabled( !signingData )
                    .disabled(showSpinner )
                    .opacity(showSpinner ? 0.5 : 1)
            }
        }
    }
}
