import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showPrivacyPolicy = false
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
                    .foregroundStyle(MaroowellTheme.deepYellow)
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
                                }                            }
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

                    if let error = sessionViewModel.errorMessage {
                        Text(error)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: submit) {
                        HStack(spacing: 8) {
                            if sessionViewModel.isSigningIn { ProgressView().tint(.white) }
                            Text(sessionViewModel.isSigningIn ? "로그인 중..." : "로그인")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)                        .frame(height: 52)
                        .background(Color(red: 0.08, green: 0.60, blue: 0.53), in: RoundedRectangle(cornerRadius: 16))
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
        .sheet(isPresented: $showPrivacyPolicy) {            NavigationStack {
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
                .tint(Color(red: 0.08, green: 0.60, blue: 0.53))
        }
        .padding(.horizontal, 14)
        .frame(height: 60)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    focused ? Color(red: 0.08, green: 0.60, blue: 0.53) : MaroowellTheme.border,
                    lineWidth: focused ? 1.5 : 1
                )
        }
    }

    private func submit() {
        focusedField = nil
        Task {
            await sessionViewModel.signIn(email: email, password: password)
        }
    }
}
