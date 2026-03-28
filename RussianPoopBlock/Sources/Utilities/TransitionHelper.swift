import UIKit

class TransitionHelper {

    static let shared = TransitionHelper()

    private let fadeDuration: TimeInterval = 1.0

    private init() {}

    func applyFadeTransition(to viewController: UIViewController, presenting: Bool) {
        guard GameSettings.shared.animationEnabled else { return }

        if presenting {
            viewController.modalPresentationStyle = .fullScreen
            viewController.view.alpha = 0
        }

        UIView.animate(withDuration: fadeDuration, animations: {
            viewController.view.alpha = presenting ? 1 : 0
        }, completion: { _ in
            if !presenting {
                viewController.dismiss(animated: false)
            }
        })
    }

    func fadeIn(_ view: UIView, completion: (() -> Void)? = nil) {
        guard GameSettings.shared.animationEnabled else {
            view.alpha = 1
            completion?()
            return
        }

        view.alpha = 0
        UIView.animate(withDuration: fadeDuration, animations: {
            view.alpha = 1
        }, completion: { _ in
            completion?()
        })
    }

    func fadeOut(_ view: UIView, completion: (() -> Void)? = nil) {
        guard GameSettings.shared.animationEnabled else {
            view.alpha = 0
            completion?()
            return
        }

        UIView.animate(withDuration: fadeDuration, animations: {
            view.alpha = 0
        }, completion: { _ in
            completion?()
        })
    }

    func createFadeTransition(isPresenting: Bool) -> CATransition {
        let transition = CATransition()
        transition.duration = fadeDuration
        transition.type = .fade
        transition.timingFunction = CAMediaTimingFunction(name: isPresenting ? .easeIn : .easeOut)
        return transition
    }
}

extension UIViewController {
    func applyPresentAnimation() {
        guard GameSettings.shared.animationEnabled else { return }
        view.alpha = 0
        UIView.animate(withDuration: 1.0) {
            self.view.alpha = 1
        }
    }

    func applyDismissAnimation(completion: (() -> Void)? = nil) {
        guard GameSettings.shared.animationEnabled else {
            dismiss(animated: false, completion: completion)
            return
        }

        UIView.animate(withDuration: 1.0, animations: {
            self.view.alpha = 0
        }, completion: { _ in
            self.dismiss(animated: false, completion: completion)
        })
    }
}
