#include "common.h"

Rcpp::Function R_serialize("serialize");
Rcpp::Function R_unserialize("unserialize");

const char* wlife_t2str(wlife_t status) {
    switch(status) {
        case wlife_t::active: return "active";
        case wlife_t::shutdown: return "shutdown";
        case wlife_t::finished: return "finished";
        case wlife_t::error: return "error";
        case wlife_t::proxy_cmd: return "proxy_cmd";
        case wlife_t::proxy_error: return "proxy_error";
        default: Rcpp::stop("Invalid worker status");
    }
}

void check_interrupt_fn(void *dummy) {
    R_CheckUserInterrupt();
}

int pending_interrupt() {
    return !(R_ToplevelExec(check_interrupt_fn, NULL));
}

zmq::message_t int2msg(const int val) {
    zmq::message_t msg(sizeof(int));
    memcpy(msg.data(), &val, sizeof(int));
    return msg;
}

zmq::message_t r2msg(SEXP data) {
    if (TYPEOF(data) != RAWSXP)
        data = R_serialize(data, R_NilValue);
    zmq::message_t msg(Rf_xlength(data));
    memcpy(msg.data(), RAW(data), Rf_xlength(data));
    return msg;
}

SEXP msg2r(const zmq::message_t &&msg, const bool unserialize) {
    SEXP ans = Rf_allocVector(RAWSXP, msg.size());
    memcpy(RAW(ans), msg.data(), msg.size());
    if (unserialize)
        return R_unserialize(ans);
    else
        return ans;
}

wlife_t msg2wlife_t(const zmq::message_t &msg) {
    wlife_t res;
    memcpy(&res, msg.data(), msg.size());
    return res;
}
