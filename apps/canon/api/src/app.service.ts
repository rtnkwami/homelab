import { Injectable } from '@nestjs/common';
import { InjectDrizzle } from '@nestjs/drizzle';
import { NodePgDatabase } from 'drizzle-orm/node-postgres';

@Injectable()
export class AppService {
  public constructor(@InjectDrizzle() private readonly db: NodePgDatabase) {}

  public getHello(): string {
    return 'Hello World!';
  }
}
