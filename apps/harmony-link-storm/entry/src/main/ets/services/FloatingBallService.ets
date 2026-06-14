import floatingBall from '@ohos.window.floatingBall';
import Want from '@ohos.app.ability.Want';
import { common } from '@kit.AbilityKit';

export class FloatingBallService {
  private static instance: FloatingBallService | undefined;
  private controller: floatingBall.FloatingBallController | undefined;
  private context: common.UIAbilityContext | undefined;
  private enabled: boolean = false;

  static getInstance(): FloatingBallService {
    if (!FloatingBallService.instance) {
      FloatingBallService.instance = new FloatingBallService();
    }
    return FloatingBallService.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async enable(): Promise<string> {
    if (!this.context) {
      throw new Error('FloatingBallService is not initialized');
    }
    if (!floatingBall.isFloatingBallEnabled()) {
      throw new Error('Floating ball is not supported on this device');
    }

    if (!this.controller) {
      this.controller = await floatingBall.create({ context: this.context });
      this.controller.on('click', async () => {
        await this.restoreMainWindow();
      });
    }

    const bundleName = this.context.applicationInfo.name;
    await this.controller.startFloatingBall({
      template: floatingBall.FloatingBallTemplate.EMPHATIC,
      title: 'Link Storm',
      content: 'Tap to capture',
      backgroundColor: '#136F63'
    });
    this.enabled = true;
    return bundleName;
  }

  async disable(): Promise<void> {
    if (!this.controller) {
      return;
    }
    await this.controller.stopFloatingBall();
    this.enabled = false;
  }

  isEnabled(): boolean {
    return this.enabled;
  }

  async restoreMainWindow(): Promise<void> {
    if (!this.context || !this.controller) {
      return;
    }
    const want = new Want();
    want.bundleName = this.context.applicationInfo.name;
    want.abilityName = 'EntryAbility';
    await this.controller.restoreMainWindow(want);
  }
}

export const floatingBallService = FloatingBallService.getInstance();
