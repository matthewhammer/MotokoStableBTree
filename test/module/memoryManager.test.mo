import MemoryManager    "../../src/memoryManager";
import Memory           "../../src/memory";
import Constants        "../../src/constants";
import { Test }         "testableItems";

import { test; suite; } "mo:test";

import Nat64            "mo:base/Nat64";
import Nat16            "mo:base/Nat16";
import Int64            "mo:base/Int64";
import Buffer           "mo:base/Buffer";
import Array            "mo:base/Array";
import Blob             "mo:base/Blob";

suite("MemoryManager test suite", func() {

  // For convenience: from the memory manager module
  type MemoryId = MemoryManager.MemoryId;
  type BucketId = MemoryManager.BucketId;
  // For convenience: from base module
  type Buffer<T> = Buffer.Buffer<T>;

  func toOptArray<T>(buffer: ?Buffer<T>) : ?[T] {
    switch(buffer){
      case(null) { null; };
      case(?buffer) { ?buffer.toArray(); };
    };
  };

  // To use less memory and avoid RTS error: Cannot grow memory
  let BUCKET_SIZE_IN_PAGES : Nat64 = 16;

  test("canGetMemory", func(){
    let mem_mgr = MemoryManager.initWithBuckets(Memory.VecMemory(), Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
    let memory = mem_mgr.get(0 : MemoryId);
    Test.equalsNat64(memory.size(), 0);
  });

  test("canAllocateAndUseMemory", func(){
    let mem = Memory.VecMemory();
    let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
    let memory = mem_mgr.get(0 : MemoryId);

    Test.equalsInt64(memory.grow(1), 0);
    Test.equalsNat64(memory.size(), 1);

    memory.write(0, Blob.fromArray([1, 2, 3]));

    let bytes = memory.read(0, 3);
    Test.equalsBytes(Blob.toArray(bytes), [1, 2, 3]);

    Test.equalsOptArrayNat16(toOptArray<Nat16>(mem_mgr.inner_.memory_buckets_.get(0 : MemoryId)), ?[0 : BucketId]);
  });

  test("canAllocateAndUseMultipleMemories", func(){
    let mem = Memory.VecMemory();
    let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
    let memory_0 = mem_mgr.get(0 : MemoryId);
    let memory_1 = mem_mgr.get(1 : MemoryId);

    Test.equalsInt64(memory_0.grow(1), 0);
    Test.equalsInt64(memory_1.grow(1), 0);

    Test.equalsNat64(memory_0.size(), 1);
    Test.equalsNat64(memory_1.size(), 1);

    Test.equalsOptArrayNat16(toOptArray<Nat16>(mem_mgr.inner_.memory_buckets_.get(0 : MemoryId)), ?[0 : BucketId]);
    Test.equalsOptArrayNat16(toOptArray<Nat16>(mem_mgr.inner_.memory_buckets_.get(1 : MemoryId)), ?[1 : BucketId]);

    memory_0.write(0, Blob.fromArray([1, 2, 3]));
    memory_0.write(0, Blob.fromArray([1, 2, 3]));
    memory_1.write(0, Blob.fromArray([4, 5, 6]));

    var bytes = memory_0.read(0, 3);
    Test.equalsBytes(Blob.toArray(bytes), [1, 2, 3]);

    bytes := memory_1.read(0, 3);
    Test.equalsBytes(Blob.toArray(bytes), [4, 5, 6]);

    // + 1 is for the header.
    Test.equalsNat64(mem.size(), 2 * BUCKET_SIZE_IN_PAGES + 1);
  });

  test("canBeReinitializedFromMemory", func(){
    let mem = Memory.VecMemory();
    var mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
    var memory_0 = mem_mgr.get(0 : MemoryId);
    var memory_1 = mem_mgr.get(1 : MemoryId);

    Test.equalsInt64(memory_0.grow(1), 0);
    Test.equalsInt64(memory_1.grow(1), 0);

    memory_0.write(0, Blob.fromArray([1, 2, 3]));
    memory_1.write(0, Blob.fromArray([4, 5, 6]));

    mem_mgr := MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
    memory_0 := mem_mgr.get(0 : MemoryId);
    memory_1 := mem_mgr.get(1 : MemoryId);

    var bytes = memory_0.read(0, 3);
    Test.equalsBytes(Blob.toArray(bytes), [1, 2, 3]);

    bytes := memory_1.read(0, 3);
    Test.equalsBytes(Blob.toArray(bytes), [4, 5, 6]);
  });

  test("growingSameMemoryMultipleTimesDoesntIncreaseUnderlyingAllocation", func(){
    let mem = Memory.VecMemory();
    let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
    let memory_0 = mem_mgr.get(0 : MemoryId);

    // Grow the memory by 1 page. This should increase the underlying allocation
    // by `BUCKET_SIZE_IN_PAGES` pages.
    Test.equalsInt64(memory_0.grow(1), 0);
    Test.equalsNat64(mem.size(), 1 + BUCKET_SIZE_IN_PAGES);

    // Grow the memory again. This should NOT increase the underlying allocation.
    Test.equalsInt64(memory_0.grow(1), 1);
    Test.equalsNat64(memory_0.size(), 2);
    Test.equalsNat64(mem.size(), 1 + BUCKET_SIZE_IN_PAGES);

    // Grow the memory up to the BUCKET_SIZE_IN_PAGES. This should NOT increase the underlying
    // allocation.
    Test.equalsInt64(memory_0.grow(BUCKET_SIZE_IN_PAGES - 2), 2);
    Test.equalsNat64(memory_0.size(), BUCKET_SIZE_IN_PAGES);
    Test.equalsNat64(mem.size(), 1 + BUCKET_SIZE_IN_PAGES);

    // Grow the memory by one more page. This should increase the underlying allocation.
    Test.equalsInt64(memory_0.grow(1), Int64.fromNat64(BUCKET_SIZE_IN_PAGES));
    Test.equalsNat64(memory_0.size(), BUCKET_SIZE_IN_PAGES + 1);
    Test.equalsNat64(mem.size(), 1 + 2 * BUCKET_SIZE_IN_PAGES);
  });

  test("doesNotGrowMemoryUnnecessarily", func(){
    let mem = Memory.VecMemory();
    let initial_size = BUCKET_SIZE_IN_PAGES * 2;

    // Grow the memory manually before passing it into the memory manager.
    ignore mem.grow(initial_size);

    let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
    let memory_0 = mem_mgr.get(0 : MemoryId);

    // Grow the memory by 1 page.
    Test.equalsInt64(memory_0.grow(1), 0);
    Test.equalsNat64(mem.size(), initial_size);

    // Grow the memory by BUCKET_SIZE_IN_PAGES more pages, which will cause the underlying
    // allocation to increase.
    Test.equalsInt64(memory_0.grow(BUCKET_SIZE_IN_PAGES), 1);
    Test.equalsNat64(mem.size(), 1 + BUCKET_SIZE_IN_PAGES * 2);
  });

  test("growingBeyondCapacityFails", func(){
    let MAX_MEMORY_IN_PAGES: Nat64 = MemoryManager.MAX_NUM_BUCKETS * BUCKET_SIZE_IN_PAGES;

    let mem = Memory.VecMemory();
    let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
    let memory_0 = mem_mgr.get(0 : MemoryId);

    Test.equalsInt64(memory_0.grow(MAX_MEMORY_IN_PAGES + 1), -1);

    // Try to grow the memory by MAX_MEMORY_IN_PAGES + 1.
    Test.equalsInt64(memory_0.grow(1), 0); // should succeed
    Test.equalsInt64(memory_0.grow(MAX_MEMORY_IN_PAGES), -1); // should fail.
  });

  test("canWriteAcrossBucketBoundaries", func(){
    let mem = Memory.VecMemory();
    let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
    let memory_0 = mem_mgr.get(0 : MemoryId);

    Test.equalsInt64(memory_0.grow(BUCKET_SIZE_IN_PAGES + 1), 0);

    memory_0.write(
      mem_mgr.inner_.bucketSizeInBytes() - 1,
      Blob.fromArray([1, 2, 3]),
    );

    let bytes = memory_0.read(
      mem_mgr.inner_.bucketSizeInBytes() - 1,
      3
    );
    Test.equalsBytes(Blob.toArray(bytes), [1, 2, 3]);
  });

  test("canWriteAcrossBucketBoundariesWithInterleavingMemories", func(){
    let mem = Memory.VecMemory();
    let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
    let memory_0 = mem_mgr.get(0 : MemoryId);
    let memory_1 = mem_mgr.get(1 : MemoryId);

    Test.equalsInt64(memory_0.grow(BUCKET_SIZE_IN_PAGES), 0);
    Test.equalsInt64(memory_1.grow(1), 0);
    Test.equalsInt64(memory_0.grow(1), Int64.fromNat64(BUCKET_SIZE_IN_PAGES));

    memory_0.write(
      mem_mgr.inner_.bucketSizeInBytes() - 1,
      Blob.fromArray([1, 2, 3]),
    );
    memory_1.write(0, Blob.fromArray([4, 5, 6]));

    var bytes = memory_0.read(Constants.WASM_PAGE_SIZE * BUCKET_SIZE_IN_PAGES - 1, 3);
    Test.equalsBytes(Blob.toArray(bytes), [1, 2, 3]);

    bytes := memory_1.read(0, 3);
    Test.equalsBytes(Blob.toArray(bytes), [4, 5, 6]);
  });

  // TODO: succeed on trap

//  test("readingOutOfBoundsShouldTrap", func(){
//    let mem = Memory.VecMemory();
//    let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
//    let memory_0 = mem_mgr.get(0 : MemoryId);
//    let memory_1 = mem_mgr.get(1 : MemoryId);
//
//    Test.equalsInt64(memory_0.grow(1), 0);
//    Test.equalsInt64(memory_1.grow(1), 0);
//
//    let bytes = memory_0.read(0, Nat64.toNat(Constants.WASM_PAGE_SIZE) + 1);
//  });

  // TODO: succeed on trap

//  test("writingOutOfBoundsShouldTrap", func(){
//    let mem = Memory.VecMemory();
//    let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
//    let memory_0 = mem_mgr.get(0 : MemoryId);
//    let memory_1 = mem_mgr.get(1 : MemoryId);
//
//    Test.equalsInt64(memory_0.grow(1), 0);
//    Test.equalsInt64(memory_1.grow(1), 0);
//
//    let bytes = Array.freeze(Array.init<Nat8>(Nat64.toNat(Constants.WASM_PAGE_SIZE) + 1, 0));
//    memory_0.write(0, Blob.fromArray(bytes));
//  });

  test("readingZeroBytesFromEmptyMemoryShouldNotTrap", func(){
    let mem = Memory.VecMemory();
    let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
    let memory_0 = mem_mgr.get(0 : MemoryId);

    Test.equalsNat64(memory_0.size(), 0);
    let bytes = memory_0.read(0, 0);
  });

  test("writingZeroBytesToEmptyMemoryShouldNotTrap", func(){
    let mem = Memory.VecMemory();
    let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
    let memory_0 = mem_mgr.get(0 : MemoryId);

    Test.equalsNat64(memory_0.size(), 0);
    memory_0.write(0, Blob.fromArray([]));
  });

});