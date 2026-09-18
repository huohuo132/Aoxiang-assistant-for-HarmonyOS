import { huks } from '@kit.UniversalKeystoreKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Config } from '../common/Config';
import { Store } from './Store';

const KEY_ALIAS: string = 'campus_login_credentials';
const GCM_TAG_LENGTH: number = 16;
const NONCE_LENGTH: number = 12;
const AAD_TEXT: string = 'campus_login_credentials_v1';

export class CredentialStore {
  static async save(username: string, password: string): Promise<boolean> {
    try {
      const payload: string = await CredentialStore.encrypt(username + '\n' + password);
      Store.put(Config.KEY_CREDENTIALS, payload);
      Store.put(Config.KEY_CREDENTIALS_VERIFIED, false);
      Store.put(Config.KEY_CREDENTIAL_FAILURE_COUNT, 0);
      return true;
    } catch (error) {
      CredentialStore.logFailure('save', error);
      return false;
    }
  }

  static async read(): Promise<Array<string>> {
    const value: string = Store.getString(Config.KEY_CREDENTIALS, '');
    if (value.length === 0) {
      return ['', ''];
    }
    const separator: number = value.indexOf(':');
    if (separator <= 0) {
      return ['', ''];
    }
    try {
      const plain: string = await CredentialStore.decrypt(
        value.substring(0, separator), value.substring(separator + 1));
      const split: number = plain.indexOf('\n');
      if (split < 0) {
        return ['', ''];
      }
      return [plain.substring(0, split), plain.substring(split + 1)];
    } catch (error) {
      return ['', ''];
    }
  }

  static clear(): void {
    Store.remove(Config.KEY_CREDENTIALS);
    Store.put(Config.KEY_CREDENTIALS_VERIFIED, false);
    Store.put(Config.KEY_CREDENTIAL_FAILURE_COUNT, 0);
  }

  private static async ensureKey(): Promise<void> {
    const existingOptions: huks.HuksOptions = { properties: [] };
    const exists: boolean = await huks.hasKeyItem(KEY_ALIAS, existingOptions);
    if (exists) {
      return;
    }
    const genOptions: huks.HuksOptions = {
      properties: [
        { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
        { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
        {
          tag: huks.HuksTag.HUKS_TAG_PURPOSE,
          value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
        },
        { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
        { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE }
      ]
    };
    await huks.generateKeyItem(KEY_ALIAS, genOptions);
  }

  private static async encrypt(plain: string): Promise<string> {
    await CredentialStore.ensureKey();
    const nonce: Uint8Array = CredentialStore.randomBytes(NONCE_LENGTH);
    const plainBytes: Uint8Array = CredentialStore.encodeUtf8(plain);
    const options: huks.HuksOptions = {
      properties: CredentialStore.gcmProperties(
        huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT, nonce),
      inData: plainBytes
    };
    const initResult: huks.HuksSessionHandle = await huks.initSession(KEY_ALIAS, options);
    const finishResult: huks.HuksReturnResult = await huks.finishSession(initResult.handle, options);
    const cipherBytes: Uint8Array | undefined = finishResult.outData;
    if (cipherBytes === undefined || cipherBytes.length <= GCM_TAG_LENGTH) {
      throw new Error('encrypt failed');
    }
    const helper: util.Base64Helper = new util.Base64Helper();
    return helper.encodeToStringSync(nonce) + ':' + helper.encodeToStringSync(cipherBytes);
  }

  private static async decrypt(nonceBase64: string, dataBase64: string): Promise<string> {
    const helper: util.Base64Helper = new util.Base64Helper();
    const nonce: Uint8Array = helper.decodeSync(nonceBase64);
    const all: Uint8Array = helper.decodeSync(dataBase64);
    if (all.length <= GCM_TAG_LENGTH) {
      throw new Error('invalid payload');
    }
    const cipher: Uint8Array = all.subarray(0, all.length - GCM_TAG_LENGTH);
    const tag: Uint8Array = all.subarray(all.length - GCM_TAG_LENGTH);
    const properties: Array<huks.HuksParam> = CredentialStore.gcmProperties(
      huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT, nonce);
    const tagParam: huks.HuksParam = { tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: tag };
    properties.push(tagParam);
    const options: huks.HuksOptions = { properties: properties, inData: cipher };
    const initResult: huks.HuksSessionHandle = await huks.initSession(KEY_ALIAS, options);
    const finishResult: huks.HuksReturnResult = await huks.finishSession(initResult.handle, options);
    const plainBytes: Uint8Array | undefined = finishResult.outData;
    if (plainBytes === undefined) {
      throw new Error('decrypt failed');
    }
    return CredentialStore.decodeUtf8(plainBytes);
  }

  private static gcmProperties(purpose: huks.HuksKeyPurpose, nonce: Uint8Array): Array<huks.HuksParam> {
    return [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
      { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: CredentialStore.encodeUtf8(AAD_TEXT) }
    ];
  }

  private static encodeUtf8(text: string): Uint8Array {
    const encoder: util.TextEncoder = new util.TextEncoder();
    return encoder.encodeInto(text);
  }

  private static decodeUtf8(bytes: Uint8Array): string {
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(bytes);
  }

  private static logFailure(stage: string, error: Object): void {
    const failure: BusinessError = error as BusinessError;
    hilog.error(0x0000, 'CredentialStore', '%{public}s failed: code=%{public}d msg=%{public}s',
      stage, failure.code, failure.message);
  }

  private static randomBytes(length: number): Uint8Array {
    const random: cryptoFramework.Random = cryptoFramework.createRandom();
    const dataBlob: cryptoFramework.DataBlob = random.generateRandomSync(length);
    return dataBlob.data;
  }
}
