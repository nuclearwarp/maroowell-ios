import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showPrivacyPolicy = false
    @AppStorage("maroowell.rememberEmail") private var rememberEmail = false
    @AppStorage("maroowell.rememberPassword") private var rememberPassword = false
    private let credentialStore = SecureCredentialStore()
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 28)

                Image("MaroowellLoginLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 242, maxHeight: 218)
                    .accessibilityLabel("마루웰")

                Text("Design the Structure.\nMove the Future.")
                    .font(.system(size: 15, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MaroowellTheme.logoGold)
                    .padding(.top, 2)
                    .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 12) {
                    Text("계정 로그인")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(MaroowellTheme.ink)
                    Text("마루웰 계정의 이메일과 비밀번호를 입력해주세요.")
                        .font(.system(size: 13))
                        .foregroundStyle(MaroowellTheme.muted)

                    outlinedField(title: "이메일", focused: focusedField == .email) {
                        TextField("이메일", text: $email)
                            .foregroundStyle(MaroowellTheme.ink)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }

                    outlinedField(title: "비밀번호", focused: focusedField == .password) {
                        HStack(spacing: 8) {
                            Group {
                                if showPassword {
                                    TextField("비밀번호", text: $password)
                                } else {
                                    SecureField("비밀번호", text: $password)
                                }
                            }
                            .foregroundStyle(MaroowellTheme.ink)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { submit() }

                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(MaroowellTheme.muted)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 18) {
                        credentialToggle(title: "아이디 저장", isOn: rememberEmail) {
                            rememberEmail.toggle()
                            if !rememberEmail {
                                rememberPassword = false
                                credentialStore.clear()
                            }
                        }

                        credentialToggle(title: "비밀번호 저장", isOn: rememberPassword) {
                            rememberPassword.toggle()
                            if rememberPassword {
                                rememberEmail = true
                            }
                        }

                        Spacer(minLength: 0)
                    }

                    if let error = sessionViewModel.errorMessage {
                        Text(error)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: submit) {
                        HStack(spacing: 8) {
                            if sessionViewModel.isSigningIn {
                                ProgressView().tint(.white)
                            }
                            Text(sessionViewModel.isSigningIn ? "로그인 중..." : "로그인")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(MaroowellTheme.primary, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(sessionViewModel.isSigningIn)
                }
                .padding(16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(MaroowellTheme.border, lineWidth: 1)
                }

                Button("개인정보 처리방침") {
                    focusedField = nil
                    showPrivacyPolicy = true
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MaroowellTheme.muted)
                .padding(.top, 16)

                Spacer(minLength: 28)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white)
        .overlay {
            if sessionViewModel.isSigningIn {
                GeometryReader { proxy in
                    ZStack {
                        Color.white.ignoresSafeArea()
                        MaroowellLoadingGIFView()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .accessibilityLabel("로그인 중")
                    }
                }
                .transition(.opacity)
                .zIndex(100)
                .allowsHitTesting(true)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: sessionViewModel.isSigningIn)
        .onAppear {
            let saved = credentialStore.load()
            rememberEmail = saved.rememberEmail
            rememberPassword = saved.rememberPassword
            if saved.rememberEmail {
                email = saved.email
            }
            if saved.rememberPassword {
                password = saved.password
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationStack {
                PrivacyPolicyView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("닫기") { showPrivacyPolicy = false }
                        }
                    }
            }
            .preferredColorScheme(.light)
        }
    }

    private func credentialToggle(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isOn ? MaroowellTheme.deepYellow : MaroowellTheme.muted)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MaroowellTheme.ink)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func outlinedField<Content: View>(
        title: String,
        focused: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MaroowellTheme.muted)
            content()
                .font(.body)
                .tint(MaroowellTheme.primary)
        }
        .padding(.horizontal, 14)
        .frame(height: 60)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    focused ? MaroowellTheme.primary : MaroowellTheme.border,
                    lineWidth: focused ? 1.5 : 1
                )
        }
    }

    private func submit() {
        focusedField = nil
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await sessionViewModel.signIn(email: normalizedEmail, password: password)
            guard sessionViewModel.session != nil else { return }
            credentialStore.save(
                email: normalizedEmail,
                password: password,
                rememberEmail: rememberEmail,
                rememberPassword: rememberPassword
            )
        }
    }
}
