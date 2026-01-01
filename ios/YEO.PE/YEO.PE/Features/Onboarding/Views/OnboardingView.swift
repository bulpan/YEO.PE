import SwiftUI
import Combine
import Foundation

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            Color.deepBlack.edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: completeOnboarding) {
                        Text("skip".localized)
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    }
                    .padding()
                }
                Spacer()
            }
            
            TabView(selection: $currentPage) {
                OnboardingPage(
                    systemImage: "dot.radiowaves.left.and.right",
                    title: "onboarding_1_title_v2".localized,
                    description: "onboarding_1_desc_v2".localized
                ).tag(0)
                
                OnboardingPage(
                    systemImage: "theatermasks.fill",
                    title: "onboarding_2_title_v2".localized,
                    description: "onboarding_2_desc_v2".localized
                ).tag(1)
                
                OnboardingPage(
                    systemImage: "clock.arrow.circlepath",
                    title: "onboarding_3_title_v2".localized,
                    description: "onboarding_3_desc_v2".localized
                ).tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            
            // Bottom Button
            VStack {
                Spacer()
                
                Button(action: {
                    if currentPage < 2 {
                        withAnimation { currentPage += 1 }
                    } else {
                        completeOnboarding()
                    }
                }) {
                    Text(currentPage < 2 ? "next".localized : "start_app".localized)
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.neonGreen)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }
    
    private func completeOnboarding() {
        withAnimation {
            hasSeenOnboarding = true
        }
    }
}

struct OnboardingPage: View {
    let systemImage: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: systemImage)
                .font(.system(size: 100))
                .foregroundColor(.neonGreen)
                .shadow(color: .neonGreen.opacity(0.5), radius: 20, x: 0, y: 0)
            
            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 28, weight: .bold)) // Larger Title
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                Text(description)
                    .font(.system(size: 17)) // Larger Body
                    .multilineTextAlignment(.center)
                    .lineSpacing(4) // Better readability
                    .foregroundColor(Color.gray.opacity(0.9))
                    .padding(.horizontal, 40)
            }
        }
        .padding(.bottom, 100)
    }
}
