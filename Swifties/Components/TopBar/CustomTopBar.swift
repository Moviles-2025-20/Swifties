import SwiftUI

struct CustomTopBar: View {
    let title: String
    let showNotificationButton: Bool
    let showBackButton: Bool
    let onNotificationTap: (() -> Void)?
    let onBackTap: (() -> Void)?
    
    init(
        title: String,
        showNotificationButton: Bool = false,
        showBackButton: Bool = false,
        onNotificationTap: (() -> Void)? = nil,
        onBackTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.showNotificationButton = showNotificationButton
        self.showBackButton = showBackButton
        self.onNotificationTap = onNotificationTap
        self.onBackTap = onBackTap
    }
    
    var body: some View {
        ZStack {
            // Rounded background (bottom corners only)
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color("appBlue"))
                .ignoresSafeArea(edges: .top)
            
            // Content
            HStack {
                // Back button aligned to leading
                if showBackButton {
                    Button(action: { onBackTap?() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    }
                    .padding(.leading, 20)
                } else {
                    Spacer()
                        .frame(width: 44) // Reserve space for symmetry
                }
                
                Spacer()
                
                // Centered title
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Notification button aligned to trailing
                if showNotificationButton {
                    Button(action: { onNotificationTap?() }) {
                        Image(systemName: "bell")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                    }
                    .padding(.trailing, 20)
                } else {
                    Spacer()
                        .frame(width: 44) // Reserve space for symmetry
                }
            }
        }
        .frame(height: 50)
    }
}
