/// When FFive may ask for an App Store review: once, after the lifter has finished a block.
public enum ReviewPrompt {
    public static func shouldAsk(finishedBlocks: Int, alreadyAsked: Bool) -> Bool {
        finishedBlocks > 0 && !alreadyAsked
    }
}
