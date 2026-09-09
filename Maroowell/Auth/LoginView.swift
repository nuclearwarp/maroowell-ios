import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPrivacyPolicy = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 54)

                MaroowellMark(size: 96)
                    .padding(.bottom, 24)

                Text("마루웰")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(MaroowellTheme.ink)

                Text("더 나은 배송의 하루를 함께해요")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MaroowellTheme.muted)
                    .padding(.top, 8)
                    .padding(.bottom, 36)

                VStack(spacing: 14) {
                    inputField(
                        title: "이메일",
                        systemImage: "envelope.fill",
                        content: {
                            TextField("name@maroowell.com", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                        }
                    )

                    inputField(
                        title: "비밀번호",
                        systemImage: "lock.fill",
                        content: {
                            SecureField("비밀번호", text: $password)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { submit() }
                        }
                    )
                }

                if let error = sessionViewModel.errorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(error)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
                }

                Button(action: submit) {
                    HStack(spacing: 10) {
                        if sessionViewModel.isSigningIn {
                            ProgressView()
                                .tint(MaroowellTheme.ink)
                        }
                        Text(sessionViewModel.isSigningIn ? "로그인 중..." : "로그인")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(MaroowellTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(MaroowellTheme.yellow, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(sessionViewModel.isSigningIn)
                .padding(.top, 24)

                Text("승인된 마루웰 계정으로 로그인해주세요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 18)

                Button("개인정보 처리방침") {
                    focusedField = nil
                    showPrivacyPolicy = true
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MaroowellTheme.muted)
                .padding(.top, 12)

                Spacer(minLength: 36)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(MaroowellTheme.background)
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationStack {
                PrivacyPolicyView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("닫기") { showPrivacyPolicy = false }
                        }
                    }
            }
        }
    }

    private func inputField<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .foregroundStyle(MaroowellTheme.deepYellow)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MaroowellTheme.muted)
                content()
                    .font(.body.weight(.semibold))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 72)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MaroowellTheme.border.opacity(0.8), lineWidth: 1)
        }
    }

    private func submit() {
        focusedField = nil
        Task {
            await sessionViewModel.signIn(email: email, password: password)
        }
    }
}
