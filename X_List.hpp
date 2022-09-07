#pragma once
#include "./X.hpp"
#include <type_traits>

// xList<tNode> type, with tNode extends xListNode
template<typename tNode>
class xList;

class xListNode
{
private:
    xListNode* pPrev;
    xListNode* pNext;

    template<typename tNode>
    friend class xList;

protected:
    xListNode() noexcept { Reset(); }
    xListNode(const xListNode & Other) noexcept { Reset(); }
    ~xListNode() noexcept { DetachUnsafe(); }

    void Reset() {
        pPrev = pNext = this;
    }
    void Detach() {
        DetachUnsafe();
        Reset();
    }
    void TakePlaceOf(xListNode& other) {
        TakePlaceOfUnsafe(other);
        other.Reset();
    }
    bool Linked() const {
        return pPrev != this;
    }

private:
    void AppendTo(xListNode& prev_node) {
        xListNode& next_node = *prev_node.pNext;
        prev_node.pNext = this;
        next_node.pPrev = this;
        pPrev = &prev_node;
        pNext = &next_node;
    }

    void DetachUnsafe() {
        pPrev->pNext = pNext;
        pNext->pPrev = pPrev;
    }

    void TakePlaceOfUnsafe(xListNode& other) {
        pPrev = other.pPrev;
        pNext = other.pNext;
        pNext->pPrev = this;
        pPrev->pNext = this;
    }

};

template<typename tNode>
class xList
{
private:
    static_assert(std::is_base_of_v<xListNode, tNode>);
    static_assert(!std::is_reference_v<tNode> && !std::is_const_v<tNode>);
    xListNode _Head;

public:
    xList() = default;
    xList(const xList&) = delete;
    xList(xList&& other) {
        GrabListTail(other);
    }
    ~xList() {
        assert(IsEmpty());
    }

private:
    template<bool isConst>
    class xForwardIteratorTemplate
    {
        using xBaseNode   = std::conditional_t<isConst, const xListNode, xListNode>;
        using xExtendNode = std::conditional_t<isConst, const tNode, tNode>;
    private:
        xBaseNode* pTarget;
        xBaseNode* pNext;

    private:
        xExtendNode* Ptr() const { return static_cast<xExtendNode*>(pTarget); }
        void Copy(xBaseNode* n) { pTarget = n; pNext = n->pNext; }

    public:
        // construct:
        xForwardIteratorTemplate() = delete;
        xForwardIteratorTemplate(xBaseNode* n) { Copy(n); }
        // for use of xList::end(),
        xForwardIteratorTemplate(xBaseNode* n, const std::nullptr_t &) { pTarget = n, pNext = nullptr; }

        // Copy:
        xForwardIteratorTemplate(const xForwardIteratorTemplate& it) = default;
        xForwardIteratorTemplate& operator=(const xForwardIteratorTemplate& it) = default;

        // cast:
        xExtendNode* operator->() const { return Ptr(); }
        xExtendNode& operator*() const { return *Ptr(); }

        // compare:
        bool operator==(const xForwardIteratorTemplate& it) const { return pTarget == it.pTarget; }
        bool operator!=(const xForwardIteratorTemplate& it) const { return pTarget != it.pTarget; }

        // traversing:
        xForwardIteratorTemplate operator++() {
            Copy(pNext);
            return *this;
        }
        xForwardIteratorTemplate operator++(int) {
            xForwardIteratorTemplate ret(*this);
            Copy(pNext);
            return ret;
        }
    };

public:
    using xForwardIterator = xForwardIteratorTemplate<false>;
    using xForwardConstIterator = xForwardIteratorTemplate<true>;

public:
    bool IsEmpty() const { return _Head.pNext == &_Head;  }
    void AddHead(tNode& rTarget) {
        static_cast<xListNode&>(rTarget).AppendTo(_Head);
    }
    void AddTail(tNode& rTarget) {
        static_cast<xListNode&>(rTarget).AppendTo(*_Head.pPrev);
    }
    void GrabHead(tNode& rTarget) {
        static_cast<xListNode&>(rTarget).DetachUnsafe();
        AddHead(rTarget);
    }
    void GrabTail(tNode& rTarget) {
        static_cast<xListNode&>(rTarget).DetachUnsafe();
        AddTail(rTarget);
    }
    void GrabListHead(xList& other) {
        if (other.IsEmpty()) {
            return;
        };
        xListNode* remoteHead = other._Head.pNext;
        xListNode* remoteTail = other._Head.pPrev;
        other.Reset();

        xListNode* localHead = _Head.pNext;
        _Head.pNext = remoteHead;
        remoteHead->pPrev = &_Head;
        localHead->pPrev = remoteTail;
        remoteTail->pNext = localHead;
    }
    void GrabListTail(xList& other) {
        if (other.IsEmpty()) {
            return;
        };
        xListNode* remoteHead = other._Head.pNext;
        xListNode* remoteTail = other._Head.pPrev;
        other._Head.Reset();

        xListNode* localTail = _Head.pPrev;
        _Head.pPrev = remoteTail;
        remoteTail->pNext = &_Head;
        localTail->pNext = remoteHead;
        remoteHead->pPrev = localTail;
    }
    tNode * Head() {
        if (IsEmpty()) {
            return nullptr;
        }
        return static_cast<tNode*>(_Head.pNext);
    }
    tNode * Tail() {
        if (IsEmpty()) {
            return nullptr;
        }
        return static_cast<tNode*>(_Head.pPrev);
    }
    tNode * PopHead() {
        if (IsEmpty()) {
            return nullptr;
        }
        auto ret = _Head.pNext;
        ret->Detach();
        return static_cast<tNode*>(ret);
    }
    tNode * PopTail() {
        if (IsEmpty()) {
            return nullptr;
        }
        auto ret = _Head.pPrev;
        ret->Detach();
        return static_cast<tNode*>(ret);
    }
    
    static void Remove(tNode& Node) {
        Node.Detach();
    }

    xForwardIterator begin() { return xForwardIterator(_Head.pNext); }
    xForwardIterator end() { return xForwardIterator(&_Head, nullptr); }

    xForwardConstIterator begin() const { return xForwardConstIterator(_Head.pNext); }
    xForwardConstIterator end() const { return xForwardConstIterator(&_Head, nullptr); }

    void ReleaseUnsafe() { _Head.Reset(); }
};
