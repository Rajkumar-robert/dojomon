import { GameObject } from "./GameObject";

export class Sprite {
  image: HTMLImageElement;
  shadow: HTMLImageElement;
  isLoaded: boolean = false;
  isShadowLoaded: boolean = false;
  useShadow: boolean;
  animations: { [key: string]: number[][] };
  currentAnimation: string;
  currentAnimationFrame: number;
  gameObject: GameObject;
  animationFrameLimit: number;
  animationFrameProgress: number;

  constructor(config: {
    gameObject: GameObject;
    src: string;
    animations?: { [key: string]: number[][] };
    currentAnimation?: string;
    useShadow?: boolean;
    animationFrameLimit?: number;
  }) {
    // Set up the image
    this.image = new Image();
    this.image.src = config.src;
    this.image.onload = () => {
      this.isLoaded = true;
    };

    // Shadow
    this.shadow = new Image();
    this.useShadow = config.useShadow ?? true;
    if (this.useShadow) {
      this.shadow.src = "/images/characters/shadow.png";
    }
    this.shadow.onload = () => {
      this.isShadowLoaded = true;
    };

    // Configure Animation & Initial State
    this.animations = config.animations || {
      "idle-down" : [ [0,0] ],
      "idle-right": [ [0,3] ],
      "idle-up"   : [ [0,2] ],
      "idle-left" : [ [0,1] ],
      "walk-down" : [ [1,0],[0,0],[3,0],[0,0], ],
      "walk-right": [ [1,2],[0,2],[3,2],[0,2], ],
      "walk-up"   : [ [1,3],[0,3],[3,3],[0,3], ],
      "walk-left" : [ [1,1],[0,1],[3,1],[0,1], ],
    };
    this.currentAnimation = config.currentAnimation || "idle-down";
    this.currentAnimationFrame = 0;
    this.animationFrameLimit = config.animationFrameLimit || 8;
    this.animationFrameProgress = this.animationFrameLimit;

    // Reference the game object
    this.gameObject = config.gameObject;
  }

  get frame(){
    return this.animations[this.currentAnimation][this.currentAnimationFrame]
  }

  setAnimation(key: string) {
    if (this.currentAnimation !== key) {
      this.currentAnimation = key;
      this.currentAnimationFrame = 0;
      this.animationFrameProgress = this.animationFrameLimit;
    }
  }

  updateAnimationProgress() {
    //Downtick frame progress
    if (this.animationFrameProgress > 0) {
      this.animationFrameProgress -= 1;
      return;
    }

    //Reset the counter
    this.animationFrameProgress = this.animationFrameLimit;
    this.currentAnimationFrame += 1;

    if (this.frame === undefined) {
      this.currentAnimationFrame = 0
    }
  }

  draw(ctx: CanvasRenderingContext2D): void {
    const x = this.gameObject.x * 12 ;
    const y = this.gameObject.y * 12 ;

    // if (this.isShadowLoaded) {
    //   ctx.drawImage(this.shadow, x, y);
    // }

    const [frameX, frameY] = this.frame;

    if (this.isLoaded) {
      ctx.drawImage(
        this.image, 
        frameX * 32, frameY * 48,
        32, 
        48, 
        x, 
        y, 
        48, 
        72,);
    }

    this.updateAnimationProgress();
  }
}
