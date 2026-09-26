import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from '../src/app.controller.js';
import { AppService } from '../src/app.service.js';
import { getDrizzleToken } from '@nestjs/drizzle';

describe('AppController', () => {
  let appController: AppController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [
        AppService,
        {
          provide: getDrizzleToken(),
          useValue: {}
        }
      ],
    }).compile();

    appController = app.get<AppController>(AppController);
  });

  describe('root', () => {
    it('should return "Hello World!"', () => {
      expect(appController.getHello()).toBe('Hello World!');
    });
  });
});
