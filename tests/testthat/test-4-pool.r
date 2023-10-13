context("pool")

test_that("starting and stopping multicore", {
    skip_on_os("windows")

    w = workers(1, qsys_id="multicore")
    expect_equal(w$workers_total, 1)
    expect_equal(w$workers_running, 0)
    expect_null(w$recv())
    expect_equal(w$workers_running, 1)
    w$send(3 + 4)
    expect_equal(w$workers_running, 1)
    expect_equal(w$recv(), 7)
    expect_equal(w$workers_running, 1)
    w$send_shutdown()
    expect_equal(w$workers_running, 0)
    expect_equal(w$workers_total, 1)
    expect_error(w$send(1))
    expect_error(w$recv())
    w$cleanup()
    expect_equal(w$workers_running, 0)
    expect_equal(w$workers_total, 0)
    expect_error(w$send(2))
    expect_error(w$recv())
    expect_equal(w$workers_running, 0)
    expect_equal(w$workers_total, 0)
})

test_that("calculations are really done on the worker", {
    skip_on_os("windows")
    x = 1
    y = 2
    w = workers(1, qsys_id="multicore")
    expect_null(w$recv())
    w$env(y = 3)
    w$send(x + y, x=4)
    expect_equal(w$recv(), 7)
    w$send_shutdown()
    w$cleanup()
})

test_that("multiprocess", {
    skip("https://github.com/r-lib/processx/issues/236")

    w = workers(1, qsys_id="multiprocess")
    expect_null(w$recv())
    w$send(3 + 5)
    expect_equal(w$recv(), 8)
    w$send_shutdown()
    w$cleanup()
})

test_that("work_chunk on multiprocess", {
    skip("https://github.com/r-lib/processx/issues/236")

    w = workers(1, qsys_id="multiprocess")
    expect_null(w$recv())
    w$send(clustermq:::work_chunk(chunk, `+`), chunk=list(a=1:3, b=4:6))
    res = w$recv()
    expect_equal(res$result, list(`1`=5, `2`=7, `3`=9))
    expect_equal(res$warnings, list())
    expect_equal(res$errors, list())
    w$send_shutdown()
    w$cleanup()
})
