import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';
import { MicroserviceOptions, Transport } from '@nestjs/microservices';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

async function bootstrap(): Promise<void> {
  const app = await NestFactory.createMicroservice<MicroserviceOptions>(
    AppModule,
    {
      transport: Transport.GRPC,
      options: {
        package: ['core.v1'],
        protoPath: [
          require.resolve('@canon/proto/schemas/core/v1/test.proto')
        ]
      }
    }
  );

  app.enableShutdownHooks();
}
await bootstrap();
