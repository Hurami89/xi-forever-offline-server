/*
===========================================================================

  Copyright (c) 2024 LandSandBoat Dev Teams

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see http://www.gnu.org/licenses/

===========================================================================
*/

#pragma once

#include <asio/ts/internet.hpp>
#include <common/logging.h>

#include <fmt/format.h>

#include <chrono>
#include <stdexcept>
#include <thread>

#include "common/scheduler/scheduler.h"
#include "search_handler.h"

namespace search_listener_detail
{

// A search server from the last session (or the game client's old connection) can keep the
// port busy for a few seconds after the launcher stops everything. Retry instead of throwing
// an uncaught exception, which used to abort the whole process before it said why.
inline auto makeSearchAcceptor(asio::io_context& context, const unsigned int port) -> asio::ip::tcp::acceptor
{
    const auto     endpoint    = asio::ip::tcp::endpoint(asio::ip::tcp::v4(), port);
    constexpr auto maxAttempts = 10;

    for (auto attempt = 1;; ++attempt)
    {
        asio::error_code ec{};

        asio::ip::tcp::acceptor acceptor(context);
        acceptor.open(endpoint.protocol(), ec);
        if (ec)
        {
            throw std::runtime_error(fmt::format("search server cannot open its listener: {}", ec.message()));
        }

        acceptor.set_option(asio::socket_base::reuse_address(true), ec);
        if (ec)
        {
            throw std::runtime_error(fmt::format("search server cannot set SO_REUSEADDR: {}", ec.message()));
        }

        acceptor.bind(endpoint, ec);
        if (!ec)
        {
            acceptor.listen(asio::socket_base::max_listen_connections, ec);
            if (ec)
            {
                throw std::runtime_error(fmt::format("search server cannot listen on port {}: {}", port, ec.message()));
            }

            return acceptor;
        }

        // Windows reports a port another program is already listening on as WSAEACCES
        // (access_denied), not WSAEADDRINUSE, so treat both as "still busy".
        const auto portBusy = ec == asio::error::address_in_use || ec == asio::error::access_denied;
        if (!portBusy || attempt >= maxAttempts)
        {
            auto message = ec.message();
            if (!message.empty() && message.back() == '.')
            {
                message.pop_back();
            }

            throw std::runtime_error(fmt::format(
                "search server cannot bind port {}: {}. Another copy of xi_search may still be running; press STOP in the launcher, wait a moment, then press PLAY again.",
                port, message));
        }

        ShowWarningFmt("search port {} is still in use; waiting one second ({}/{})", port, attempt, maxAttempts);
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
}

} // namespace search_listener_detail

class SearchListener
{
public:
    SearchListener(Scheduler& scheduler, const unsigned int port, SynchronizedShared<std::unordered_set<std::string>>& ipWhitelist)
    : scheduler_(scheduler)
    , acceptor_(search_listener_detail::makeSearchAcceptor(scheduler_.mainContext(), port))
    , ipWhitelist_(ipWhitelist)
    {
        scheduler_.postToMainThread(accept_loop());
    }

private:
    auto accept_loop() -> Task<void>
    {
        // Run "forever"
        while (!scheduler_.closeRequested())
        {
            auto [ec, socket] = co_await acceptor_.async_accept(asio::as_tuple(asio::use_awaitable));

            if (!ec)
            {
                const auto handler = std::make_shared<SearchHandler>(scheduler_, std::move(socket), ipInFlight_, ipWhitelist_);
                scheduler_.postToMainThread(handler->run());
            }
            else
            {
                ShowErrorFmt("Failed to accept connection: {}", ec.message());
            }
        }
    }

    Scheduler&              scheduler_;
    asio::ip::tcp::acceptor acceptor_;

    SynchronizedShared<std::unordered_set<std::string>>& ipWhitelist_;
    SynchronizedShared<std::map<std::string, uint16_t>>  ipInFlight_;
};
