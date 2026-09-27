import { Controller } from '@nestjs/common';
import { AppService } from './app.service.js';
import { GrpcMethod } from '@nestjs/microservices';

@Controller()
export class AppController {
  public constructor(private readonly appService: AppService) {}

  @GrpcMethod()
  public getHello(): string {
    return this.appService.getHello();
  }
}
