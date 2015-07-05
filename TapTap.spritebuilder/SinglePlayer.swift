//
//  Gameplay.swift
//  TapTap
//
//  Created by Zachary Espiritu on 6/30/15.
//  Copyright (c) 2015 Apportable. All rights reserved.
//

import Foundation

class SinglePlayer: CCNode {
    
    // MARK: Constants
    
    let moveAmount: CGFloat = 0.03      // How much does the line move on a correct tap?
    let wrongTapPenalty: CGFloat = 0.07 // How much does the line move on an incorrect tap?
    
    let numberOfTileRows: Int = 5       // How many tile rows do we generate for each array?
    
    let xDelay = 0.15                   // How long does the incorrect X mark appear in milliseconds?
    let animationDelay = 0.04           // How long does it take for a tileRow animation to complete?
    
    let audio = OALSimpleAudio.sharedInstance() // OALSimpleAudio instance used for handling sounds.
    
    
    // MARK: Memory Variables
    
    let defaults = NSUserDefaults.standardUserDefaults()
    
    // See `OptionsMenu.swift` for information on these constants.
    let ingameParticlesKey = "ingameParticlesKey"
    let backgroundMusicKey = "backgroundMusicKey"
    let soundEffectsKey = "soundEffectsKey"
    
    let leftSideColorChoice = "leftSideColorChoice"
    let rightSideColorChoice = "rightSideColorChoice"
    
    let singlePlayerHighScore = "singlePlayerHighScore"
    
    
    // MARK: Variables
    
    var countdown: String = "0" {
        didSet { // Called during the `countdownBeforeGameBegins()` sequence. Every time the countdown variable changes, it changes the label output of the `redCountdownLabel` and the `blueCountdownLabel`.
            blueCountdownLabel.string = String("\(countdown)")
        }
    }
    weak var blueCountdownLabel: CCLabelTTF! // of each game.
    
    weak var blueWarningGradient: CCNode!    // when a player is about to lose.
    
    weak var dominantColor: DominantColor!   // The enclosing node of the color that is the only one that actually "moves". Scales on the x-axis in order to give the impression that it is getting larger/smaller.
    weak var particleLine: ParticleLine!     // The particle line that hides the color fade between the two sides.
    
    weak var world: CCNode!                  // Used for animation handling in Gameplay.ccb.
    
    // Variables used to handle the infinite generation of tileRows. Two sets exist to handle both players' sets individually.
    weak var blueTileRowNode: CCNode!
    var blueTileRows: [TileRow] = []
    var blueIndex: Int = 0
    
    // Variables used to handle the each of the red X's that appears when you tap on an incorrect box.
    weak var blueX1, blueX2, blueX3, blueX4: CCSprite!
    
    var warningSound = false // Used in the "locking" mechanism for the warningSound. See `checkForWarningSound()` below.
    
    var gameState: GameState = .Initial // Used to check if the game is in a state where the players are allowed to make moves. Prevents players from discovering a bug where you can continue playing the game even after the game has ended and is in the Main Menu.
    
    weak var dominantColorNode, backgroundColorNode: CCNodeColor! // Defaults to blue. Used to change the color as specified in `OptionsMenu.swift`.
    
    weak var fasterLabel: CCLabelTTF!
    
    weak var scoreHeader: CCLabelTTF!
    weak var scoreLabel: CCLabelTTF!
    var score: Int = 0 {
        didSet {
            scoreLabel.string = "\(score)"
        }
    }
    var level: Int = 0 {
        didSet {
            scheduleComputerPlayer(level: level)
        }
    }
    
    var timeRemainingInLevel: Int = 0
    var currentInterval: Double = 0
    
    
    // MARK: Reset Functions
    
    /**
    Called whenever the `SinglePlayer.ccb` file loads.
    */
    func didLoadFromCCB() {
        
        self.animationManager.runAnimationsForSequenceNamed("Gameplay")
        
        for index in 0..<numberOfTileRows {
            
            // Duplicate the tileRow. We have to do this since we can't add the same piece as a child to two different nodes.
            var blueTileRow = CCBReader.load("TileRow") as! TileRow
            
            var rowWidth = 0
            
            // Cascade opacity is enabled so we can just apply the opacity to a single node as opposed to having to change each box individually.
            blueTileRow.cascadeOpacityEnabled = true
            
            // Depending on the row, modify its properties to achieve the desired effect.
            if index == 1 {
                blueTileRow.scaleX = 50/70
                rowWidth = 81
            }
            else if index == 2 {
                blueTileRow.scaleX = 40/70
                rowWidth = 140
            }
            else if index == 3 {
                blueTileRow.scaleX = 20/70
                rowWidth = 190
            }
            else if index == 4 {
                blueTileRow.scaleX = 10/70
                rowWidth = 220
            }
            
            // Update each row's position based on the above control if-statement.
            blueTileRow.position = CGPoint(x: rowWidth, y: 0)
            
            // Generate a random tile row for the redTileRow and the blueTileRow.
            blueTileRow.generateRandomTileRow()
            
            // Add the tileRow as a child of its respective TileRowNode. This allows us to position it relative to the TileRowNode.
            blueTileRowNode.addChild(blueTileRow)
            
            // Append the tileRow to the end of its respective TileRow array.
            blueTileRows.append(blueTileRow)
            
        }
        
        // For whatever reason, if we tried to change the opacity for each of the rows in the above for loop, it wouldn't change - however, if we do it in a separate for loop, it ends up working. I'm not even going to ask why - it just works!
        for index in 0..<blueTileRows.count {
            
            var currentBlueRow = blueTileRows[index]
            
            if index == 0 {
                currentBlueRow.opacity = 0.95
            }
            else if index == 1 {
                currentBlueRow.opacity = 0.85
            }
            else if index == 2 {
                currentBlueRow.opacity = 0.70
            }
            else if index == 3 {
                currentBlueRow.opacity = 0.50
            }
            else if index == 4 {
                currentBlueRow.opacity = 0.25
            }
            
        }
        
        if defaults.boolForKey(soundEffectsKey) { // Check if sound effects are enabled in the options. No need to preload sounds if they aren't!
            audio.preloadEffect("siren.mp3")
            audio.preloadEffect("tap.wav")
            audio.preloadEffect("scratch.wav")
            audio.preloadEffect("buzz.wav")
        }
        
        if defaults.boolForKey(backgroundMusicKey) { // Check if background music/sound is enabled in the options.
            audio.playBg("gameplayBG.mp3", loop: true)
        }
        
        if !defaults.boolForKey(ingameParticlesKey) {
            particleLine.stopParticleGeneration()
        }
        
        getColorChoicesFromMemory() // Load all color choices from `NSUserDefaults` and change the visual appearance of both sides, all in one swoop. See `getColorChoicesFromMemory()` below.
        
        gameState = .Playing // Change the gameState to Playing to allow players to begin making moves.
        countdownBeforeGameBegins() // Start the pre-game countdown, which will automatically begin the game.
        
    }
    
    
    // MARK: Primed Game State Functions
    
    /**
    Launches a 3-second countdown before the game begins.
    
    `TileRows` are left visible during this countdown on purpose to give a few seconds to the players so they can get acquainted with the starting generation of tiles before the game truly starts.
    */
    func countdownBeforeGameBegins() {
        blueCountdownLabel.visible = true
        
        self.countdown = "READY?"
        delay(1.2) {
            self.countdown = "3"
            self.delay(1) {
                self.countdown = "2"
                self.delay(1) {
                    self.countdown = "1"
                    self.scoreHeader.runAction(CCActionFadeOut(duration: 0.7))
                    self.delay(1) {
                        // Enable user interaction on "GO!".
                        self.countdown = "GO!"
                        self.userInteractionEnabled = true
                        self.multipleTouchEnabled = true
                        self.delay(0.4) {
                            // Remove the "GO!" after a slight pause. No need to wait another full second since the players will already know what to do.
                            self.blueCountdownLabel.visible = false
                            self.level = 1
                            return
                        }
                    }
                }
            }
        }
    }
    
    /**
    When called, delays the running of code included in the `closure` parameter.
    */
    func delay(delay:Double, closure:()->()) {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(delay * Double(NSEC_PER_SEC))
            ),
            dispatch_get_main_queue(), closure)
    }
    
    
    // MARK: Single-Player Specific Functions
    
    func scheduleComputerPlayer(#level: Int) {
        
        if level == 1 {
            currentInterval = 0.8
        }
        else if level == 2 {
            currentInterval = 0.6
        }
        else if level == 3 {
            currentInterval = 0.5
        }
        else if level == 4 {
            currentInterval = 0.4
        }
        else if level == 5 {
            currentInterval = 0.35
        }
        else if level == 6 {
            currentInterval = 0.3
        }
        else if level == 7 {
            currentInterval = 0.25
        }
        else if level == 8 {
            currentInterval = 0.2
        }
        else {
            currentInterval = 0.2 - (Double(level - 8) * 0.02)
        }
        
        self.schedule("tick", interval: currentInterval)
        
        self.scheduleOnce("levelTimer", delay: 15)
        self.schedule("updateTimeRemainingVariable", interval: 1)
        timeRemainingInLevel = 15
        
    }
    
    func tick() {
        // Move the particleLine to stay with the dominantColor edge.
        particleLine.position.x -= moveAmount
        
        // Move the dominantColor towards its goal.
        dominantColor.right(Float(moveAmount))
        
        score++
        
        if !checkIfWin() {
            checkForWarning()
        }
    }
    
    func levelTimer() {
        
        self.unschedule("tick")
        self.unschedule("updateTimeRemainingVariable")
        
        displayFasterLabel()
        
        if dominantColor.scaleX > 0.5 {
            
            self.userInteractionEnabled = false
            
            dominantColor.runAction(CCActionScaleTo(duration: 0.5, scaleX: 0.5, scaleY: 1))
            particleLine.runAction(CCActionMoveTo(duration: 0.5, position: CGPoint(x: 0.5, y: 0.5)))
            
            delay(0.5) {
                self.userInteractionEnabled = true
                self.multipleTouchEnabled = true
                self.level++
            }
            
        }
        else {
            level++
        }
        
    }
    
    func updateTimeRemainingVariable() {
        timeRemainingInLevel--
    }
    
    /**
    To be run whenever a state occurs where blue wins.
    
    Triggers end-game animation sequences.
    */
    func overrideLevelComplete() {
        
        self.userInteractionEnabled = false
        
        self.unschedule("tick")
        self.unschedule("levelTimer")
        self.unschedule("updateTimeRemainingVariable")
        
        displayFasterLabel()
        
        dominantColor.runAction(CCActionScaleTo(duration: 0.8, scaleX: 0.5, scaleY: 1))
        particleLine.runAction(CCActionMoveTo(duration: 0.8, position: CGPoint(x: 0.5, y: 0.5)))
        
        var scoreMultiplier: Double = pow(1.2, Double(level))
        var possiblePointsRemaining: Double = Double(timeRemainingInLevel) / currentInterval
        
        score += Int(possiblePointsRemaining * scoreMultiplier)
        
        delay(0.8) {
            self.userInteractionEnabled = true
            self.multipleTouchEnabled = true
            self.level++
        }
        
    }
    
    func displayFasterLabel() {
        
        let startingPosition: CGPoint = CGPoint(x: 0.5, y: -0.5)
        let bounceInAction = CCActionEaseBounceIn(action: CCActionMoveTo(duration: 0.5, position: CGPoint(x: 0.5, y: 0.5)))
        let bounceOutAction = CCActionEaseBounceOut(action: CCActionMoveTo(duration: 0.5, position: CGPoint(x: 0.5, y: 1.5)))
        
        let actionsArray = [bounceInAction, bounceOutAction]
        let sequence = CCActionSequence(array: actionsArray)
        
        fasterLabel.position = startingPosition
        fasterLabel.runAction(sequence)
        
        
    }
    
    // MARK: In-Game Functions
    
    /**
    Called whenever a tap on the screen occurs.
    
    It checks to see which side of the screen the tap occured, and passes that information along to the `checkIfRightTap()` function for further processing.
    
    In addition, it calls the `checkIfWin()` function to determine if the tap action caused the game to land in a win state. If `checkIfWin()` returns false, it calls the `checkForWarning()` function to determine if the tap action caused the game to land in a state where it should display a `warningGradient` to one of the players.
    */
    override func touchBegan(touch: CCTouch!, withEvent event: CCTouchEvent!) {
        
        if gameState == .Playing { // Check to see if the `gameState` is currently Playing. Used to prevent people from continuing to make moves while the game is in the menu phase.
            var taplocation = touch.locationInNode(world)
            
            var xTouch = taplocation.x
            var screenHalf = CCDirector.sharedDirector().viewSize().width / 2
            
            if xTouch < screenHalf { // A tap on the blue side.
                checkIfRightTap(side: .Blue, location: taplocation)
                
            }
            
            // Check to see if the tap caused a win. If not, check to see if the tap caused the game to enter a warning state for one of the players.
            if !checkIfWin() {
                checkForWarning()
            }
        }
        
    }
    
    
    // MARK: Checking Functions
    
    /**
    Called whenever a tap occurs by `touchBegan()`.
    
    Checks to see if the tap caused the game to land in a state where it should display a `warningGradient` to one of the players. Also, checks to see if the tap caused the game to do the reverse - if the tap caused the game to leave one of the two possible warning states.
    */
    func checkForWarning() {
        
        var scale = dominantColor.scaleX
        
        if scale <= 0.22 {
            if scale <= 0.22 {
                blueWarningGradient.visible = true
            }
            
            // "Locking" mechanism to prevent the `siren.mp3` being repeatedly played on every tap that would result in a "Warning" state.
            if !warningSound {
                warningSound = true
                checkForWarningSound()
            }
        }
        else {
            blueWarningGradient.visible = false
            
            audio.stopAllEffects()
            
            warningSound = false // "Unlocks" the locking mechanism detailed above.
        }
        
    }
    
    /**
    Checks to see if a warning sound should be played.
    */
    func checkForWarningSound() {
        
        if warningSound {
            
            if defaults.boolForKey(soundEffectsKey) { // Check if sound effects are enabled in the options.
                audio.playEffect("siren.mp3", volume: 0.08, pitch: 1.0, pan: 0.0, loop: true)
            }
            
        }
        
    }
    
    /**
    Checks if a tap landed in the correct box on a `TileRow`.
    
    Called whenever a tap occurs by `touchBegan()`, which passes the `Side` and the `CGPoint` of the tap location to the function.
    
    :param: side      The `Side` on which the tap occured.
    :param: location  The `CGPoint` at which the tap occured.
    */
    func checkIfRightTap(#side: Side, location: CGPoint) {
        
        if side == .Blue { // Blue player tapped.
            
            var tileRow = blueTileRows[blueIndex]
            var rowBox: BoxNumber = tileRow.enumBox
            
            var yTouch = location.y
            var screenQuartersVertical = CCDirector.sharedDirector().viewSize().height / 4
            
            // Compare the tap location against the enumBox of the selected tileRow to see if it was tapped in the right spot.
            if yTouch > 0 && yTouch < screenQuartersVertical && rowBox == .Bottom || yTouch > screenQuartersVertical && yTouch < (screenQuartersVertical * 2) && rowBox == .Midbottom || yTouch > (screenQuartersVertical * 2) && yTouch < (screenQuartersVertical * 3) && rowBox == .Midtop || yTouch > (screenQuartersVertical * 3) && yTouch < (screenQuartersVertical * 4) && rowBox == .Top {
                
                // Change the drawing order.
                tileRow.zOrder = tileRow.zOrder + 1
                
                // Randomly select a new tile to be colored.
                tileRow.generateRandomTileRow()
                
                // Run animation sequence to adjust each tile row individually and move it into the next slot.
                for index in 0..<numberOfTileRows {
                    
                    var newIndex = (blueIndex + index) % numberOfTileRows
                    var nextUpRow = blueTileRows[newIndex]
                    
                    var scaleUpRow: CCActionScaleTo? = nil
                    var moveTileRowDown: CCActionMoveTo? = nil
                    var opacityChange: CCActionFadeTo? = nil
                    
                    if index == 0 {
                        nextUpRow.scaleX = 10/70
                        nextUpRow.position = CGPoint(x: 220, y: 0)
                        nextUpRow.cascadeOpacityEnabled = true
                        nextUpRow.opacity = 0.25
                    }
                    else if index == 1 {
                        scaleUpRow = CCActionScaleTo(duration: animationDelay, scaleX: 70/70, scaleY: 1)
                        moveTileRowDown = CCActionMoveTo(duration: animationDelay, position: CGPoint(x: 0, y: 0))
                        opacityChange = CCActionFadeTo(duration: animationDelay, opacity: 0.95)
                    }
                    else if index == 2 {
                        scaleUpRow = CCActionScaleTo(duration: animationDelay, scaleX: 50/70, scaleY: 1)
                        moveTileRowDown = CCActionMoveTo(duration: animationDelay, position: CGPoint(x: 81, y: 0))
                        opacityChange = CCActionFadeTo(duration: animationDelay, opacity: 0.85)
                    }
                    else if index == 3 {
                        scaleUpRow = CCActionScaleTo(duration: animationDelay, scaleX: 40/70, scaleY: 1)
                        moveTileRowDown = CCActionMoveTo(duration: animationDelay, position: CGPoint(x: 140, y: 0))
                        opacityChange = CCActionFadeTo(duration: animationDelay, opacity: 0.70)
                    }
                    else if index == 4 {
                        scaleUpRow = CCActionScaleTo(duration: animationDelay, scaleX: 20/70, scaleY: 1)
                        moveTileRowDown = CCActionMoveTo(duration: animationDelay, position: CGPoint(x: 190, y: 0))
                        opacityChange = CCActionFadeTo(duration: animationDelay, opacity: 0.50)
                    }
                    
                    if index != 0 {
                        nextUpRow.runAction(scaleUpRow!)
                        nextUpRow.runAction(moveTileRowDown)
                        nextUpRow.cascadeOpacityEnabled = true
                        nextUpRow.runAction(opacityChange)
                    }
                    
                }
                
                // Cycle through the numbers 1 - numberOfTileRows in the blueIndex.
                blueIndex = (blueIndex + 1) % numberOfTileRows
                
                // Move the particleLine to stay with the dominantColor edge.
                particleLine.position.x += moveAmount
                
                // Move the dominantColor towards its goal.
                dominantColor.left(Float(moveAmount))
                
                if defaults.boolForKey(soundEffectsKey) { // Check if sound effects are enabled in the options.
                    audio.playEffect("tap.wav")
                }
                
            }
            else {
                
                // If the player tapped on the wrong square, move the dominantColor away from its goal.
                dominantColor.right(Float(wrongTapPenalty))
                
                // Move the particleLine to stay with the dominantColor edge.
                particleLine.position.x -= wrongTapPenalty
                
                if yTouch > 0 && yTouch < screenQuartersVertical { // Incorrect tap on Bottom box (box1).
                    blueX1.visible = true
                    blueX1.runAction(CCActionFadeOut(duration: xDelay))
                }
                else if yTouch > screenQuartersVertical && yTouch < (screenQuartersVertical * 2) { // Incorrect tap on Midbottom box (box2).
                    blueX2.visible = true
                    blueX2.runAction(CCActionFadeOut(duration: xDelay))
                }
                else if yTouch > (screenQuartersVertical * 2) && yTouch < (screenQuartersVertical * 3) { // Incorrect tap on Midtop box (box3).
                    blueX3.visible = true
                    blueX3.runAction(CCActionFadeOut(duration: xDelay))
                }
                else if yTouch > (screenQuartersVertical * 3) && yTouch < (screenQuartersVertical * 4) { // Incorrect tap on Top box (box4).
                    blueX4.visible = true
                    blueX4.runAction(CCActionFadeOut(duration: xDelay))
                }
                
                if defaults.boolForKey(soundEffectsKey) { // Check if sound effects are enabled in the options.
                    audio.playEffect("buzz.wav")
                }
                
            }
            
        }
        
    }
    
    /**
    Checks at every tap if a Win state has occured as a result of the tap.
    
    Returns a Boolean variable for outside functions to determine if a win occured.
    
    :returns:  Returns `true` if a win occured as a result of the tap. Returns `false` in all other cases.
    */
    func checkIfWin() -> Bool {
        var scale = dominantColor.scaleX
        
        if scale <= -0.01 { // We have a 0.01 difference on each of the possible win states to ensure that no graphical glitches occur in the end-game state.
            
            redWins()
            
            // Stop all music and play some end-game tunes.
            audio.stopAllEffects()
            if defaults.boolForKey(backgroundMusicKey) { // Check if background music/sound is enabled in the options.
                audio.playEffect("scratch.wav")
                audio.playBg("outsideBG.wav", loop: true)
            }
            
            // Change the `gameState` to GameOver to prevent people from continuing to play the game on the now-invisible TileRows.
            gameState = .GameOver
            
            return true
        }
        else if scale >= 1.01 {
            overrideLevelComplete()
        }
        
        return false
    }
    
    
    // MARK: End-Game Functions
    
    /**
    To be run whenever a state occurs where red wins.
    
    Triggers end-game animation sequences.
    */
    func redWins() {
        fasterLabel.visible = false
        
        self.userInteractionEnabled = false
        
        self.unschedule("tick")
        self.unschedule("levelTimer")
        
        fadeOutTileRows()
        
        world.animationManager.runAnimationsForSequenceNamed("RedWins")
        particleLine.stopParticleGeneration()
        
        blueWarningGradient.visible = false
        scoreHeader.opacity = 1
        
        var currentHighScore = defaults.integerForKey(singlePlayerHighScore)
        
        if score > currentHighScore {
            defaults.setInteger(score, forKey: singlePlayerHighScore)
        }
    }
    
    /**
    Runs an animation sequence on the `TileRowNodes` to fade them out of view.
    
    `cascadeOpacityEnabled = true` is used to apply the opacity effect to the `tileRows` that are children of the nodes.
    */
    func fadeOutTileRows() {
        blueTileRowNode.cascadeOpacityEnabled = true
        blueTileRowNode.runAction(CCActionFadeOut(duration: 0.3))
    }
    
    
    // MARK: Button Functions
    
    /**
    Resets the Gameplay to its original state and restarts the game.
    */
    func playAgain() {
        var gameplayScene = CCBReader.load("SinglePlayer") as! SinglePlayer
        gameplayScene.animationManager.runAnimationsForSequenceNamed("Gameplay")
        
        var scene = CCScene()
        scene.addChild(gameplayScene)
        
        var transition = CCTransition(fadeWithDuration: 0.5)
        CCDirector.sharedDirector().presentScene(scene, withTransition: transition)
    }
    
    /**
    Brings the game back to the mainMenu with some animation for polish.
    */
    func mainMenu() {
        var mainScene = CCBReader.load("MainScene") as! MainScene
        
        var scene = CCScene()
        scene.addChild(mainScene)
        
        var transition = CCTransition(fadeWithDuration: 0.5)
        CCDirector.sharedDirector().presentScene(scene, withTransition: transition)
    }
    
    
    // MARK: Memory Functions
    
    func getColorChoicesFromMemory() {
        
        // Color presets.
        var turquoiseColor = CCColor(red: 26/255, green: 188/255, blue: 156/255)
        var grayColor = CCColor(red: 52/255, green: 73/255, blue: 94/255)
        var orangeColor = CCColor(red: 230/255, green: 126/255, blue: 34/255)
        var redColor = CCColor(red: 255/255, green: 102/255, blue: 102/255)
        var silverColor = CCColor(red: 189/255, green: 195/255, blue: 199/255)
        var yellowColor = CCColor(red: 241/255, green: 196/255, blue: 15/255)
        var purpleColor = CCColor(red: 155/255, green: 89/255, blue: 182/255)
        var blueColor = CCColor(red: 0/255, green: 0/255, blue: 255/255)
        var greenColor = CCColor(red: 39/255, green: 174/255, blue: 96/255)
        
        // Restore previously set color choices.
        var leftColorChoiceInt = defaults.integerForKey(leftSideColorChoice)
        if leftColorChoiceInt == 1 { // Turquoise
            dominantColorNode.color = turquoiseColor
        }
        else if leftColorChoiceInt == 2 { // Gray
            dominantColorNode.color = grayColor
        }
        else if leftColorChoiceInt == 3 { // Orange
            dominantColorNode.color = orangeColor
        }
        else if leftColorChoiceInt == 4 { // Red
            dominantColorNode.color = redColor
        }
        else if leftColorChoiceInt == 5 { // Silver
            dominantColorNode.color = silverColor
        }
        else if leftColorChoiceInt == 6 { // Yellow
            dominantColorNode.color = yellowColor
        }
        else if leftColorChoiceInt == 7 { // Purple
            dominantColorNode.color = purpleColor
        }
        else if leftColorChoiceInt == 8 { // Blue
            dominantColorNode.color = blueColor
        }
        else if leftColorChoiceInt == 9 { // Green
            dominantColorNode.color = greenColor
        }
        
        var rightColorChoiceInt = defaults.integerForKey(rightSideColorChoice)
        if rightColorChoiceInt == 1 { // Turquoise
            backgroundColorNode.color = turquoiseColor
        }
        else if rightColorChoiceInt == 2 { // Gray
            backgroundColorNode.color = grayColor
        }
        else if rightColorChoiceInt == 3 { // Orange
            backgroundColorNode.color = orangeColor
        }
        else if rightColorChoiceInt == 4 { // Red
            backgroundColorNode.color = redColor
        }
        else if rightColorChoiceInt == 5 { // Silver
            backgroundColorNode.color = silverColor
        }
        else if rightColorChoiceInt == 6 { // Yellow
            backgroundColorNode.color = yellowColor
        }
        else if rightColorChoiceInt == 7 { // Purple
            backgroundColorNode.color = purpleColor
        }
        else if rightColorChoiceInt == 8 { // Blue
            backgroundColorNode.color = blueColor
        }
        else if rightColorChoiceInt == 9 { // Green
            backgroundColorNode.color = greenColor
        }
        
    }
    
}