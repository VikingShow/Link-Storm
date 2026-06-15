import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import { common } from '@kit.AbilityKit';

export class PermissionService {
  private static instance: PermissionService | undefined;
  private atManager: abilityAccessCtrl.AtManager;
  private context: common.UIAbilityContext;

  private constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.atManager = abilityAccessCtrl.createAtManager();
  }

  static getInstance(context: common.UIAbilityContext): PermissionService {
    if (!PermissionService.instance) {
      PermissionService.instance = new PermissionService(context);
    }
    return PermissionService.instance;
  }

  async request(permission: string): Promise<boolean> {
    try {
      const result = await this.atManager.requestPermissionsFromUser(this.context, [permission as never]);
      return result.authResults.length > 0 && result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch {
      return false;
    }
  }

  async requestMicrophone(): Promise<boolean> {
    return this.request('ohos.permission.MICROPHONE');
  }
}
