import React, { useState, useEffect } from 'react';

const InquiryModal = ({ inquiry, onClose, onAnswer }) => {
    const [answer, setAnswer] = useState('');
    const [isSubmitting, setIsSubmitting] = useState(false);

    if (!inquiry) return null;

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!answer.trim()) return;

        setIsSubmitting(true);
        await onAnswer(inquiry.id, answer);
        setIsSubmitting(false);
    };

    const isAnswered = inquiry.status === 'answered';

    return (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-lg p-6 max-w-2xl w-full max-h-[90vh] overflow-y-auto">
                <div className="flex justify-between items-center mb-4">
                    <h3 className="text-xl font-bold">Inquiry Details</h3>
                    <button onClick={onClose} className="text-gray-500 hover:text-gray-700">✕</button>
                </div>

                <div className="mb-6 space-y-4">
                    <div className="flex gap-4 text-sm text-gray-500 border-b pb-2">
                        <span>User: {inquiry.nickname || 'Unknown'}</span>
                        <span>Category: <span className="font-semibold text-gray-700 uppercase">{inquiry.category}</span></span>
                        <span>Date: {new Date(inquiry.created_at).toLocaleString()}</span>
                    </div>

                    <div className="bg-gray-50 p-4 rounded-lg">
                        <h4 className="text-sm font-semibold text-gray-500 mb-2">Question</h4>
                        <p className="whitespace-pre-wrap text-gray-800">{inquiry.content}</p>
                    </div>

                    {isAnswered && (
                        <div className="bg-blue-50 p-4 rounded-lg border border-blue-100">
                            <h4 className="text-sm font-semibold text-blue-600 mb-2">My Answer ({new Date(inquiry.answered_at).toLocaleString()})</h4>
                            <p className="whitespace-pre-wrap text-gray-800">{inquiry.answer}</p>
                        </div>
                    )}
                </div>

                {!isAnswered ? (
                    <form onSubmit={handleSubmit}>
                        <div className="mb-4">
                            <label className="block text-sm font-medium text-gray-700 mb-2">Reply</label>
                            <textarea
                                value={answer}
                                onChange={(e) => setAnswer(e.target.value)}
                                className="w-full h-32 p-3 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                                placeholder="Type your answer here..."
                                required
                            />
                        </div>
                        <div className="flex justify-end gap-2">
                            <button
                                type="button"
                                onClick={onClose}
                                className="px-4 py-2 text-gray-600 hover:bg-gray-100 rounded-lg"
                            >
                                Cancel
                            </button>
                            <button
                                type="submit"
                                disabled={isSubmitting}
                                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
                            >
                                {isSubmitting ? 'Sending...' : 'Send Answer'}
                            </button>
                        </div>
                    </form>
                ) : (
                    <div className="flex justify-end">
                        <button
                            onClick={onClose}
                            className="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300"
                        >
                            Close
                        </button>
                    </div>
                )}
            </div>
        </div>
    );
};

export default function Inquiries() {
    const [inquiries, setInquiries] = useState([]);
    const [loading, setLoading] = useState(true);
    const [selectedInquiry, setSelectedInquiry] = useState(null);
    const [filter, setFilter] = useState('all'); // 'all', 'pending', 'answered'
    const [pagination, setPagination] = useState({ page: 1, total: 0, pages: 1 });

    const fetchInquiries = async (page = 1) => {
        try {
            setLoading(true);
            const token = localStorage.getItem('adminToken');
            const res = await fetch(`/api/admin/inquiries?status=${filter}&page=${page}`, {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            if (res.ok) {
                const data = await res.json();
                setInquiries(data.inquiries);
                setPagination(data.pagination);
            }
        } catch (error) {
            console.error('Failed to fetch inquiries:', error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchInquiries(1);
    }, [filter]);

    const handleAnswer = async (id, answer) => {
        try {
            const token = localStorage.getItem('adminToken');
            const res = await fetch(`/api/admin/inquiries/${id}/answer`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({ answer })
            });

            if (res.ok) {
                setSelectedInquiry(null);
                fetchInquiries(pagination.page); // Refresh list
            } else {
                alert('Failed to submit answer');
            }
        } catch (error) {
            console.error('Error answering inquiry:', error);
            alert('Error submitting answer');
        }
    };

    return (
        <div className="p-6">
            <div className="flex justify-between items-center mb-6">
                <h1 className="text-2xl font-bold">1:1 Inquiries</h1>
                <div className="flex gap-2">
                    {['all', 'pending', 'answered'].map((status) => (
                        <button
                            key={status}
                            onClick={() => setFilter(status)}
                            className={`px-4 py-2 rounded-lg capitalize ${filter === status
                                    ? 'bg-blue-600 text-white'
                                    : 'bg-white text-gray-600 border hover:bg-gray-50'
                                }`}
                        >
                            {status}
                        </button>
                    ))}
                </div>
            </div>

            {loading ? (
                <div className="text-center py-10">Loading...</div>
            ) : (
                <div className="bg-white rounded-lg shadow overflow-hidden">
                    <table className="min-w-full divide-y divide-gray-200">
                        <thead className="bg-gray-50">
                            <tr>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Category</th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Content</th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Action</th>
                            </tr>
                        </thead>
                        <tbody className="bg-white divide-y divide-gray-200">
                            {inquiries.map((inquiry) => (
                                <tr key={inquiry.id} className="hover:bg-gray-50">
                                    <td className="px-6 py-4 whitespace-nowrap">
                                        <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${inquiry.status === 'answered' ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'
                                            }`}>
                                            {inquiry.status}
                                        </span>
                                    </td>
                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 capitalize">
                                        {inquiry.category}
                                    </td>
                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                        {inquiry.nickname || 'Unknown'}
                                    </td>
                                    <td className="px-6 py-4 text-sm text-gray-900 max-w-xs truncate">
                                        {inquiry.content}
                                    </td>
                                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                        {new Date(inquiry.created_at).toLocaleDateString()}
                                    </td>
                                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                                        <button
                                            onClick={() => setSelectedInquiry(inquiry)}
                                            className="text-blue-600 hover:text-blue-900"
                                        >
                                            View
                                        </button>
                                    </td>
                                </tr>
                            ))}
                            {inquiries.length === 0 && (
                                <tr>
                                    <td colSpan="6" className="px-6 py-10 text-center text-gray-500">No inquiries found</td>
                                </tr>
                            )}
                        </tbody>
                    </table>

                    {/* Pagination */}
                    {pagination.pages > 1 && (
                        <div className="px-6 py-3 flex items-center justify-between border-t border-gray-200 bg-gray-50">
                            <div className="flex-1 flex justify-between sm:hidden">
                                <button
                                    onClick={() => fetchInquiries(pagination.page - 1)}
                                    disabled={pagination.page === 1}
                                    className="relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50"
                                >
                                    Previous
                                </button>
                                <button
                                    onClick={() => fetchInquiries(pagination.page + 1)}
                                    disabled={pagination.page === pagination.pages}
                                    className="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50"
                                >
                                    Next
                                </button>
                            </div>
                            <div className="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
                                <div>
                                    <p className="text-sm text-gray-700">
                                        Showing page <span className="font-medium">{pagination.page}</span> of <span className="font-medium">{pagination.pages}</span>
                                    </p>
                                </div>
                                <div>
                                    <nav className="relative z-0 inline-flex rounded-md shadow-sm -space-x-px" aria-label="Pagination">
                                        {/* Simplified Pagination for now */}
                                        <button
                                            onClick={() => fetchInquiries(pagination.page - 1)}
                                            disabled={pagination.page === 1}
                                            className="relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50"
                                        >
                                            Previous
                                        </button>
                                        <button
                                            onClick={() => fetchInquiries(pagination.page + 1)}
                                            disabled={pagination.page === pagination.pages}
                                            className="relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50"
                                        >
                                            Next
                                        </button>
                                    </nav>
                                </div>
                            </div>
                        </div>
                    )}
                </div>
            )}

            {selectedInquiry && (
                <InquiryModal
                    inquiry={selectedInquiry}
                    onClose={() => setSelectedInquiry(null)}
                    onAnswer={handleAnswer}
                />
            )}
        </div>
    );
}
