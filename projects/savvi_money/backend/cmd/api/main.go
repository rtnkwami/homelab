package main

import (
	"context"
	"log"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	config, err := pgxpool.ParseConfig(os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}

	pool, _ := pgxpool.NewWithConfig(context.Background(), config)

	err = pool.Ping(context.Background())
	if err != nil {
		log.Fatal(err)
	}

	defer pool.Close()
}
