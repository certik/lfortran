! Sparse matrix-vector multiply in CSR (Compressed Sparse Row) format.
!
! The n x n tridiagonal matrix tridiag(-1, 2, -1) is first built in COO
! (coordinate) format, then converted to CSR, and finally multiplied by a
! vector. The Lean model of this file is in SparseLean/Sparse.lean.
module sparse_mod
implicit none
integer, parameter :: dp = kind(0.d0)

contains

! Build tridiag(-1, 2, -1) in COO format with nnz = 3n - 2 entries. The
! entries are deliberately not sorted by row: first the diagonal, then the
! sub-diagonal, then the super-diagonal.
subroutine tridiag_coo(n, row, col, val)
integer, intent(in) :: n
integer, intent(out) :: row(3*n-2), col(3*n-2)
real(dp), intent(out) :: val(3*n-2)
integer :: i, k
k = 0
do i = 1, n
    k = k + 1
    row(k) = i
    col(k) = i
    val(k) = 2
end do
do i = 2, n
    k = k + 1
    row(k) = i
    col(k) = i - 1
    val(k) = -1
end do
do i = 1, n - 1
    k = k + 1
    row(k) = i
    col(k) = i + 1
    val(k) = -1
end do
end subroutine

! Convert an n x n matrix with nnz entries from COO to CSR format.
subroutine coo2csr(n, nnz, row, col, val, row_ptr, col_ind, csr_val)
integer, intent(in) :: n, nnz, row(nnz), col(nnz)
real(dp), intent(in) :: val(nnz)
integer, intent(out) :: row_ptr(n+1), col_ind(nnz)
real(dp), intent(out) :: csr_val(nnz)
integer :: next(n), i, k, r, p
! Count the entries in each row: row_ptr(r+1) = number of entries in row r
do i = 1, n + 1
    row_ptr(i) = 0
end do
do k = 1, nnz
    row_ptr(row(k)+1) = row_ptr(row(k)+1) + 1
end do
! Prefix sum: row r occupies positions row_ptr(r), ..., row_ptr(r+1)-1
row_ptr(1) = 1
do i = 1, n
    row_ptr(i+1) = row_ptr(i+1) + row_ptr(i)
end do
! Scatter the entries into their rows; next(r) is the next free position
do i = 1, n
    next(i) = row_ptr(i)
end do
do k = 1, nnz
    r = row(k)
    p = next(r)
    col_ind(p) = col(k)
    csr_val(p) = val(k)
    next(r) = p + 1
end do
end subroutine

! y = A x for an n x n matrix A with nnz entries in CSR format.
subroutine csr_matvec(n, nnz, row_ptr, col_ind, val, x, y)
integer, intent(in) :: n, nnz, row_ptr(n+1), col_ind(nnz)
real(dp), intent(in) :: val(nnz), x(n)
real(dp), intent(out) :: y(n)
integer :: i, k
do i = 1, n
    y(i) = 0
    do k = row_ptr(i), row_ptr(i+1) - 1
        y(i) = y(i) + val(k) * x(col_ind(k))
    end do
end do
end subroutine

end module

program sparse
use sparse_mod, only: dp, tridiag_coo, coo2csr, csr_matvec
implicit none
integer, parameter :: n = 5, nnz = 3*n - 2
integer :: row(nnz), col(nnz), row_ptr(n+1), col_ind(nnz)
real(dp) :: val(nnz), csr_val(nnz), x(n), y(n)
integer :: i
call tridiag_coo(n, row, col, val)
call coo2csr(n, nnz, row, col, val, row_ptr, col_ind, csr_val)
do i = 1, n
    x(i) = i
end do
call csr_matvec(n, nnz, row_ptr, col_ind, csr_val, x, y)
print *, "row_ptr:", row_ptr
print *, "col_ind:", col_ind
print *, "y:", y
! For x = (1, 2, ..., n): y = (0, ..., 0, n+1)
do i = 1, n - 1
    if (y(i) /= 0) error stop
end do
if (y(n) /= n + 1) error stop
end program
