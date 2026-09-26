import { Injectable } from '@nestjs/common';
import { InjectDrizzle } from '@nestjs/drizzle';
import type { NodePgDatabase } from 'drizzle-orm/node-postgres';

@Injectable()
export class AppService {
  public constructor(@InjectDrizzle() db: NodePgDatabase) {}

  public getHello(): string {
    return 'Hello World!';
  }
}
