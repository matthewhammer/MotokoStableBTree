import StableBTree      "../../../src/btreemap";
import StableBTreeTypes "../../../src/types";
import Conversion       "../../../src/conversion";
import Memory           "../../../src/memory";
import BytesConverter   "../../../src/bytesConverter";

import Result           "mo:base/Result";
import Array            "mo:base/Array";
import Buffer           "mo:base/Buffer";
import Iter             "mo:base/Iter";
import Region           "mo:base/Region";

actor class SingleBTree() {
  
  // For convenience: from StableBTree types
  type InsertError = StableBTreeTypes.InsertError;
  // For convenience: from base module
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  // Arbitrary use of (Nat32, Text) for (key, value) types
  type K = Nat32;
  type V = Text;

  // Arbitrary limitation on text size (in bytes)
  let MAX_VALUE_SIZE : Nat32 = 100;

  stable let region = Region.new();

  let btreemap_ = StableBTree.init<K, V>(
    Memory.RegionMemory(region),
    BytesConverter.NAT32_CONVERTER,
    BytesConverter.textConverter(MAX_VALUE_SIZE)
  );

  public func getLength() : async Nat64 {
    btreemap_.getLength();
  };

  public func insert(key: K, value: V) : async Result<?V, InsertError> {
    btreemap_.insert(key, value);
  };

  public func get(key: K) : async ?V {
    btreemap_.get(key);
  };

  public func containsKey(key: K) : async Bool {
    btreemap_.containsKey(key);
  };

  public func isEmpty() : async Bool {
    btreemap_.isEmpty();
  };

  public func remove(key: K) : async ?V {
    btreemap_.remove(key);
  };

  public func insertMany(entries: [(K, V)]) : async Result<(), [InsertError]> {
    let buffer = Buffer.Buffer<InsertError>(0);
    for ((key, value) in Array.vals(entries)){
      switch(btreemap_.insert(key, value)){
        case(#err(insert_error)) { buffer.add(insert_error); };
        case(_) {};
      };
    };
    if (buffer.size() > 0){
      #err(Buffer.toArray(buffer));
    } else {
      #ok;
    };
  };

  public func getMany(keys: [K]) : async [V] {
    let buffer = Buffer.Buffer<V>(0);
    for (key in Array.vals(keys)){
      switch(btreemap_.get(key)){
        case(?value) { buffer.add(value); };
        case(null) {};
      };
    };
    Buffer.toArray(buffer);
  };

  public func containsKeys(keys: [K]) : async Bool {
    for (key in Array.vals(keys)){
      if (not btreemap_.containsKey(key)) {
        return false;
      };
    };
    return true;
  };

  public func removeMany(keys: [K]) : async [V] {
    let buffer = Buffer.Buffer<V>(0);
    for (key in Array.vals(keys)){
      switch(btreemap_.remove(key)){
        case(?value) { buffer.add(value); };
        case(null) {};
      };
    };
    Buffer.toArray(buffer);
  };

  public func empty() : async () {
    let entries = Iter.toArray(btreemap_.iter());
    for ((key, _) in Array.vals(entries)){
      ignore btreemap_.remove(key);
    };
  };

};
