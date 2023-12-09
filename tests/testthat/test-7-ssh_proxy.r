context("ssh proxy")

has_localhost = has_connectivity("127.0.0.1")

# in the following 2 tests, passing the context is deactivated because running
# the first test twice leads to a segfault; not sure why, fix this eventually
test_that("simple forwarding works", {
    skip_if_not(has_localhost)

    m = methods::new(CMQMaster)
    p = methods::new(CMQProxy)#, m$context())
    w = methods::new(CMQWorker)#, m$context())
    addr1 = m$listen("tcp://127.0.0.1:*")#"inproc://master")
    addr2 = p$listen("tcp://127.0.0.1:*")#"inproc://proxy")
    m$add_pending_workers(1L)
    p$connect(addr1, 500L)
    w$connect(addr2, 500L)
    expect_true(p$process_one())
    expect_null(m$recv(500L)) # worker up
    m$send(5 + 2)
    expect_true(p$process_one())
    expect_true(w$process_one())
    expect_true(p$process_one())
    result = m$recv(500L)
    expect_equal(result, 7)

    w$close()
    p$close(0L)
    m$close(0L)
})

test_that("proxy communication yields submit args", {
    skip_if_not(has_localhost)
    skip_on_cran()

    m = methods::new(CMQMaster)
    p = methods::new(CMQProxy)#, m$context())
    addr1 = m$listen("tcp://127.0.0.1:*")#"inproc://master")
    addr2 = p$listen("tcp://127.0.0.1:*")#"inproc://proxy")

    # direct connection, no ssh forward here
    p$connect(addr1, 500L)
    p$proxy_request_cmd()
    m$proxy_submit_cmd(list(n_jobs=1), 500L)
    args = p$proxy_receive_cmd()

    expect_true(inherits(args, "list"))
    expect_true("n_jobs" %in% names(args))

    p$close(0L)
    m$close(0L)
})

test_that("using the proxy without pool and forward", {
    skip_on_cran()
    skip_on_os("windows")
    skip_if_not(has_localhost)
    skip_if(toupper(getOption("clustermq.scheduler", qsys_default)) != "MULTICORE",
            message="options(clustermq.scheduler') must be 'MULTICORE'")

    m = methods::new(CMQMaster)
    addr = m$listen("tcp://127.0.0.1:*")
    p = parallel::mcparallel(ssh_proxy(sub(".*:", "", addr)))

    m$proxy_submit_cmd(list(n_jobs=1), 5000L)
    m$add_pending_workers(1L)
    expect_null(m$recv(1000L)) # worker 1 up
    m$send(5 + 2)
    expect_equal(m$recv(500L), 7) # collect results

    m$send_shutdown()
    m$close(500L)

    pr = parallel::mccollect(p, wait=TRUE, timeout=0.5)
    expect_equal(names(pr), as.character(p$pid))
})

test_that("using the proxy without pool and forward, 2 workers", {
    skip_on_cran()
    skip_on_os("windows")
    skip_if_not(has_localhost)
    skip_if(toupper(getOption("clustermq.scheduler", qsys_default)) != "MULTICORE",
            message="options(clustermq.scheduler') must be 'MULTICORE'")

    m = methods::new(CMQMaster)
    addr = m$listen("tcp://127.0.0.1:*")
    p = parallel::mcparallel(ssh_proxy(sub(".*:", "", addr)))

    m$proxy_submit_cmd(list(n_jobs=2), 5000L)
    m$add_pending_workers(2L)
    expect_null(m$recv(1000L)) # worker 1 up
    m$send({ Sys.sleep(0.5); 5 + 2 })
    expect_null(m$recv(500L)) # worker 2 up
    m$send({ Sys.sleep(0.5); 3 + 1 })
    r1 = m$recv(1000L)
    m$send_shutdown()
    r2 = m$recv(500L)
    m$send_shutdown()
    expect_equal(sort(c(r1,r2)), c(4,7))

    m$close(500L)
    pr = parallel::mccollect(p, wait=TRUE, timeout=0.5)
    expect_equal(names(pr), as.character(p$pid))
})

test_that("full SSH connection", {
    skip_on_cran()
    skip_on_os("windows")
    skip_if_not(has_localhost)
    skip_if_not(has_ssh_cmq("127.0.0.1"))

    # 'LOCAL' mode (default) will not set up required sockets
    # 'SSH' mode would lead to circular connections
    # schedulers may have long delay (they start in fresh session, so no path)
    sched = getOption("clustermq.scheduler", qsys_default)
    skip_if(is.null(sched) || toupper(sched) != "MULTICORE",
            message="options(clustermq.scheduler') must be 'MULTICORE'")
    options(clustermq.template = "SSH", clustermq.ssh.host="127.0.0.1")

    w = workers(n_jobs=1, qsys_id="ssh", reuse=FALSE)
    result = Q(identity, 42, n_jobs=1, timeout=10L, workers=w)
    expect_equal(result, list(42))

    w = workers(n_jobs=2, qsys_id="ssh", reuse=FALSE)
    result = clustermq::Q(Sys.sleep, time=c(1,2), n_jobs=2)
    expect_equal(result, list(NULL, NULL))
})
