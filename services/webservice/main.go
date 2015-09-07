package main

import (
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/boltdb/bolt"
)

var db *bolt.DB

func handleBoltError(err error) {
	if err != nil {
		panic(err)
		log.Fatal(err)
	}
}

func updateAndGetCount() string {
	// setup if necessary
	var count string
	var err error
	if db == nil {
		db, err = bolt.Open("/data/db/my.db", 0600, nil)
		handleBoltError(err)
		err = db.Update(func(tx *bolt.Tx) error {
			b, err := tx.CreateBucketIfNotExists([]byte("counter"))
			if b.Get([]byte("count")) == nil {
				err = b.Put([]byte("count"), []byte(strconv.Itoa(0)))
			}
			return err
		})
		handleBoltError(err)
	}
	// increment counter
	err = db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte("counter"))
		v, _ := strconv.Atoi(string(b.Get([]byte("count"))))
		count = strconv.Itoa(v + 1)
		err := b.Put([]byte("count"), []byte(count))
		return err
	})
	handleBoltError(err)
	return count
}

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		switch os.Getenv("SERVICE") {
		case "bot":
			w.Header().Set("Content-Type", "text/plain")
			w.Write([]byte("I'm a bot, don't trust me.\n"))
		case "db":
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte("{\"count\":\"" + updateAndGetCount() + "\"}"))
		case "api":
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte("{\"hello\":\"world\"}"))
		default:
			w.Header().Set("Content-Type", "text/plain")
			w.Write([]byte("Hello World\n"))
		}
	})
	http.ListenAndServe(":"+os.Getenv("PORT"), nil)
}
