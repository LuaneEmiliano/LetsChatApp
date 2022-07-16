//
//  ChatLogView.swift
//  LetsChatApp
//
//  Created by luane Niejelski on 7/14/22.
//

import SwiftUI
import Firebase

class ChatLogViewModel: ObservableObject {
    
    @Published var chatText = " "
    @Published var errorMessage = " "
    
    @Published var chatMessages = [ChatMessage]()
    
    var chatUser: ChatUser?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        
        fetchMessages()
        
    }
    
    var firestoreListener: ListenerRegistration?
    
    func fetchMessages() {
        
    guard let fromId = FirebaseManager.shared.auth.currentUser?.uid
        else { return }
        guard let told = chatUser?.uid else { return }
        firestoreListener?.remove()
        chatMessages.removeAll()
        firestoreListener = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.messages)
            .document(fromId)
            .collection(told)
            .order(by: FirebaseConstants.timestamp)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for messages: \(error)"
                    print(error)
                    return
                    
                }
                
                querySnapshot?.documentChanges.forEach({ change in
                    if change.type == .added {
                        do {
                            if let cm = try? change.document.data(as: ChatMessage.self) {
                                self.chatMessages.append(cm)
                                print("Appending chatMessage in ChatLogView: \(Date())")
                            }
                        } catch {
                            print("Failed to decode message: \(error)")
                        }
                       
                    }
                })
                
                DispatchQueue.main.async {
                    self.count += 1
                }
            }
    }
    
    //Responsible for send the messages to the users blue and white.
    func handleSend() {
        print(chatText)
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid
        else { return }
        
        guard let told = chatUser?.uid else { return }
        
        let document = FirebaseManager.shared.firestore.collection(FirebaseConstants.messages)
            .document(fromId)
            .collection(told)
            .document()
        
        
        let messageData = [FirebaseConstants.fromId: fromId, FirebaseConstants.toId: told, FirebaseConstants.text: self.chatText, FirebaseConstants.timestamp: Timestamp() ] as
        [String : Any]

        document.setData(messageData) { error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message into Firestore: \(error)"
                return
            }
            
            print("Successfully saved current user sending message")
            
            self.persistRecentMessage()
            
            self.chatText = " "
            self.count += 1
        }
        
        let recipientMessageDocument =
        FirebaseManager.shared.firestore
            .collection("messages")
            .document(told)
            .collection(fromId)
            .document()
        
        recipientMessageDocument.setData(messageData) {
            error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message into Firestore: \(error)"
                return
            }
            
            print("Recipient saved message as well")
        }
    }
    
    private func persistRecentMessage() {
        guard let chatUser = chatUser else { return }
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = self.chatUser?.uid else { return }
        
        let document =  FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .document(toId)
        
        let data = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: self.chatText,
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageUrl: chatUser.profileImageUrl,
            FirebaseConstants.email: chatUser.email
        ] as [String : Any]
        
        document.setData(data) { error in
            if let error = error {
                self.errorMessage = "Failed to save recent message: \(error)"
                print("Failed to save recent message: \(error)")
                return
                
            }
        }
                guard let currentUser = FirebaseManager.shared.currentUser else { return }
                        let recipientRecentMessageDictionary = [
                            FirebaseConstants.timestamp: Timestamp(),
                            FirebaseConstants.text: self.chatText,
                            FirebaseConstants.fromId: uid,
                            FirebaseConstants.toId: toId,
                            FirebaseConstants.profileImageUrl: currentUser.profileImageUrl,
                            FirebaseConstants.email: currentUser.email
                        ] as [String : Any]
        
                        FirebaseManager.shared.firestore
                            .collection(FirebaseConstants.recentMessages)
                            .document(toId)
                            .collection(FirebaseConstants.messages)
                            .document(chatUser.uid)
                            .setData(recipientRecentMessageDictionary) { error in
                                if let error = error {
                                    print("Failed to save recipient recent message: \(error)")
                                    return
                                }
                            }
        
    }
    
    @Published var count = 0
}

struct ChatLogView: View {
@ObservedObject var vm: ChatLogViewModel
    
    
    var body: some View {
        ZStack {
            messagesView
            Text(vm.errorMessage)
        }
        .navigationTitle(vm.chatUser?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            vm.firestoreListener?.remove()
        }
    }
    
    static let emptyScrollToString = "Empty"
    
    
    private var messagesView: some View {
        VStack {
            if #available(iOS 15.0, *) {
                ScrollView {
                    ScrollViewReader { scrollViewProxy in
                        VStack {
                            ForEach(vm.chatMessages) { message in
                                MessageView(message: message)
                            }
                            
                            HStack{ Spacer() }
                            .id(Self.emptyScrollToString)
                        }
                        .onReceive(vm.$count) { _ in
                            withAnimation(.easeOut(duration: 0.5)) {
                                scrollViewProxy.scrollTo("Empty", anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color(.init(white: 0.95, alpha: 1)))
                .safeAreaInset(edge: .bottom) {
                    chatBottomBar
                        .background(Color(.systemBackground).ignoresSafeArea())
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }
    private var chatBottomBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 24))
                .foregroundColor(Color(.darkGray))
            
            ZStack {
                DescriptionPlaceholder()
                TextEditor(text: $vm.chatText)
                    .opacity(vm.chatText.isEmpty ? 0.5 : 1)
            }
            .frame( height: 50)
            
            Button {
                vm.handleSend()
            } label: {
                Text("Send")
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct MessageView: View {
    
    let message: ChatMessage
    
    var body: some View {
        VStack {
            if message.fromId == FirebaseManager.shared.auth.currentUser?.uid {
                HStack {
                    Spacer()
                    HStack {
                        Text(message.text)
                            .foregroundColor(.white)
                        
                    }
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            } else {
                HStack {
                    HStack {
                        Text(message.text)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        
    }
}

private struct DescriptionPlaceholder: View {
    var body: some View {
        HStack {
            Text("Description")
                .foregroundColor(Color(.gray))
                .font(.system(size: 17))
                .padding(.leading, 5)
                .padding(.top, -4)
            Spacer()
        }
    }
}


struct ChatLogView_Previews: PreviewProvider {
    static var previews: some View {
        //        NavigationView {
        //            ChatLogView(vm: .init(chatUser: ["uid" : "3KfEGvhSAwR7QCMlcRqyG0NFLGT2", "email": "waterfall23@gmail.com"]))
        //            //            MainMessageView()
        //        }
        MainMessagesView()
    }
}
