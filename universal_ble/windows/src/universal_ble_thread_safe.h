#include <iostream>
#include <list>
#include <map>
#include <mutex>
#include <shared_mutex>
#include <thread>

namespace universal_ble
{
    // Thread Safe Map wrapper
    // Use only if you don't care about value ownership and it's OK to work with copies of the data.
    template <typename Key, typename Value>
    class ThreadSafeMap
    {
    private:
        std::unordered_map<Key, Value> data;
        mutable std::shared_mutex mutex;

    public:
        void insert_or_assign(const Key &key, const Value &value)
        {
            std::unique_lock lock(mutex);
            data.insert_or_assign(key, value);
        }

        bool remove(const Key &key)
        {
            std::unique_lock lock(mutex);
            return data.erase(key) > 0;
        }

        std::optional<Value> get(const Key &key) const
        {
            std::shared_lock lock(mutex);
            auto it = data.find(key);
            return (it != data.end()) ? std::optional<Value>(it->second) : std::nullopt;
        }

        void clear()
        {
            std::unique_lock lock(mutex);
            data.clear();
        }

        std::map<Key, Value> get_snapshot() const
        {
            std::shared_lock lock(mutex);
            return data;
        }
    };

} // namespace universal_ble
