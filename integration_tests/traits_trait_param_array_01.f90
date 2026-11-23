! Arrays of trait objects of a trait parameter (#18485): the component
! `class(U), allocatable :: elements(:)` of the generic type
! `Vector{Trait :: U}` and `class(P)` array dummies and locals of generic
! procedures `{Trait :: P}`. The elements of such an array share one dynamic
! type, as those of a runtime trait array of a named trait do (TD-46).
! `Vector{IShape}` and `Vector{ILogger}` hold several element types: they
! grow by allocating with a trait object SOURCE and assigning elements,
! their elements dispatch, are inquired, copied out and inspected with
! SELECT TYPE, and they are reallocated with another element type,
! assigned as components and deallocated.
! GFortran does not accept this LFortran extension.
module traits_trait_param_array_01_traits
    implicit none
    private
    public :: IShape, ILogger, Square, Rect, Logger, Loud

    abstract interface :: IShape
        integer function area(self)
            type(itself), intent(in), pass :: self
        end function area
        subroutine scale(self, k)
            type(itself), intent(inout), pass :: self
            integer, intent(in) :: k
        end subroutine scale
    end interface IShape

    abstract interface :: ILogger
        integer function log(self, n)
            type(itself), intent(in), pass :: self
            integer, intent(in) :: n
        end function log
    end interface ILogger

    type, implements(IShape) :: Square
        integer :: side = 1
    contains
        procedure :: area => square_area
        procedure :: scale => square_scale
    end type Square

    ! A larger element with an allocatable component, copied deeply.
    type, implements(IShape) :: Rect
        real(8) :: pad(3) = 0
        integer, allocatable :: wh(:)
    contains
        procedure :: area => rect_area
        procedure :: scale => rect_scale
    end type Rect

    type, implements(ILogger) :: Logger
        integer :: level = 10
    contains
        procedure :: log => logger_log
    end type Logger

    type, implements(ILogger) :: Loud
        integer :: factor = 2
    contains
        procedure :: log => loud_log
    end type Loud

contains

    integer function square_area(self)
        class(Square), intent(in) :: self
        square_area = self%side**2
    end function square_area

    subroutine square_scale(self, k)
        class(Square), intent(inout) :: self
        integer, intent(in) :: k
        self%side = self%side * k
    end subroutine square_scale

    integer function rect_area(self)
        class(Rect), intent(in) :: self
        rect_area = -1
        if (allocated(self%wh)) rect_area = self%wh(1) * self%wh(2)
    end function rect_area

    subroutine rect_scale(self, k)
        class(Rect), intent(inout) :: self
        integer, intent(in) :: k
        self%wh = self%wh * k
    end subroutine rect_scale

    integer function logger_log(self, n)
        class(Logger), intent(in) :: self
        integer, intent(in) :: n
        logger_log = self%level + n
    end function logger_log

    integer function loud_log(self, n)
        class(Loud), intent(in) :: self
        integer, intent(in) :: n
        loud_log = self%factor * n
    end function loud_log
end module traits_trait_param_array_01_traits

module traits_trait_param_array_01_vector
    implicit none
    private
    public :: Vector, count_items, first, fill, swap_ends, counted_twice

    type, sealed :: Vector{Trait :: U}
        class(U), allocatable :: elements(:)
    contains
        procedure, pass :: append
        procedure, pass :: get
        procedure, pass :: length
        procedure, pass :: clear
    end type Vector

contains

    ! The elements keep the dynamic type of the first item.
    subroutine append(self, item)
        type(Vector{U}), intent(inout) :: self
        class(U), intent(in) :: item
        class(U), allocatable :: old(:)
        integer :: n, i
        if (.not. allocated(self%elements)) then
            allocate(self%elements(1), source=item)
            return
        end if
        n = size(self%elements)
        allocate(old(n), source=self%elements(1))
        do i = 2, n
            old(i) = self%elements(i)
        end do
        deallocate(self%elements)
        allocate(self%elements(n + 1), source=item)
        do i = 1, n
            self%elements(i) = old(i)
        end do
    end subroutine append

    function get(self, i) result(r)
        type(Vector{U}), intent(in) :: self
        integer, intent(in) :: i
        class(U), allocatable :: r
        r = self%elements(i)
    end function get

    integer function length(self)
        type(Vector{U}), intent(in) :: self
        length = 0
        if (allocated(self%elements)) length = size(self%elements)
    end function length

    subroutine clear(self)
        type(Vector{U}), intent(inout) :: self
        if (allocated(self%elements)) deallocate(self%elements)
    end subroutine clear

    integer function count_items{Trait :: P}(a) result(n)
        class(P), intent(in) :: a(:)
        n = size(a)
    end function count_items

    ! A local array, a section passed on and an element copied out.
    function first{Trait :: P}(a) result(r)
        class(P), intent(in) :: a(:)
        class(P), allocatable :: r
        class(P), allocatable :: copy(:)
        allocate(copy(lbound(a, 1):ubound(a, 1)), source=a(1))
        if (count_items{P}(copy(1:1)) /= 1) error stop "section"
        r = copy(1)
    end function first

    subroutine fill{Trait :: P}(x, n, a)
        class(P), intent(in) :: x
        integer, intent(in) :: n
        class(P), allocatable, intent(out) :: a(:)
        allocate(a(0:n - 1), source=x)
    end subroutine fill

    subroutine swap_ends{Trait :: P}(a)
        class(P), intent(inout) :: a(:)
        class(P), allocatable :: t
        integer :: n
        n = size(a)
        t = a(1)
        a(1) = a(n)
        a(n) = t
    end subroutine swap_ends

    integer function counted_twice{Trait :: P}(a) result(n)
        class(P), allocatable, intent(in) :: a(:)
        n = count_items{P}(a) + count_items{P}(a(2:))
    end function counted_twice
end module traits_trait_param_array_01_vector

program traits_trait_param_array_01
    use traits_trait_param_array_01_traits
    use traits_trait_param_array_01_vector
    implicit none
    type :: Scene
        integer :: id = 0
        type(Vector{IShape}) :: shapes
    end type Scene
    type(Vector{IShape}) :: squares, rects
    type(Vector{ILogger}) :: logs
    type(Scene) :: s1, s2
    class(IShape), allocatable :: shape, arr(:)
    class(ILogger), allocatable :: lg
    type(Square) :: plain(4)
    integer :: i, total

    ! Grow a vector of squares and dispatch through its elements.
    if (squares%length() /= 0) error stop 1
    do i = 1, 4
        call squares%append(Square(i))
    end do
    if (squares%length() /= 4 .or. size(squares%elements) /= 4) error stop 2
    if (lbound(squares%elements, 1) /= 1 .or. ubound(squares%elements, 1) /= 4) error stop 3
    total = 0
    do i = 1, squares%length()
        total = total + squares%elements(i)%area()
    end do
    if (total /= 1 + 4 + 9 + 16) error stop 4
    call squares%elements(2)%scale(5)
    if (squares%elements(2)%area() /= 100) error stop 5
    shape = squares%get(2)
    select type (shape)
    type is (Square)
        if (shape%side /= 10) error stop 6
    class default
        error stop 7
    end select
    call shape%scale(2)
    if (shape%area() /= 400 .or. squares%elements(2)%area() /= 100) error stop 8
    ! An element is assigned a value or a trait object of its dynamic type.
    squares%elements(4) = Square(6)
    squares%elements(3) = shape
    if (squares%elements(4)%area() /= 36 .or. squares%elements(3)%area() /= 400) error stop 32
    squares%elements(1) = squares%elements(3)
    if (squares%elements(1)%area() /= 400) error stop 33

    ! Elements with an allocatable component are copied deeply.
    do i = 1, 3
        call rects%append(Rect(wh=[i, 10]))
    end do
    if (rects%length() /= 3) error stop 9
    call rects%elements(1)%scale(3)
    if (rects%elements(1)%area() /= 90 .or. rects%elements(3)%area() /= 30) error stop 10
    shape = rects%get(3)
    select type (shape)
    type is (Rect)
        if (any(shape%wh /= [3, 10])) error stop 11
    class default
        error stop 12
    end select

    ! A vector reallocated with another element type.
    call squares%clear()
    if (allocated(squares%elements) .or. squares%length() /= 0) error stop 13
    call squares%append(Rect(wh=[2, 2]))
    call squares%append(rects%get(2))
    if (squares%length() /= 2 .or. squares%elements(2)%area() /= 20) error stop 14

    ! A vector of loggers: the element type is the first item's.
    call logs%append(Logger(1))
    call logs%append(Logger(2))
    call logs%append(Logger(3))
    total = 0
    do i = 1, logs%length()
        total = total + logs%elements(i)%log(100)
    end do
    if (total /= 306) error stop 15
    lg = logs%get(3)
    if (lg%log(0) /= 3) error stop 16
    call logs%clear()
    call logs%append(Loud(3))
    call logs%append(Loud(4))
    if (logs%elements(2)%log(5) /= 20 .or. logs%length() /= 2) error stop 17

    ! Generic procedures over arrays of class(P).
    if (count_items{IShape}(rects%elements) /= 3) error stop 18
    if (count_items(rects%elements) /= 3) error stop 19
    if (count_items{IShape}(plain) /= 4) error stop 20
    if (count_items{IShape}(plain(1:3:2)) /= 2) error stop 21
    shape = first{IShape}(rects%elements)
    if (shape%area() /= 90) error stop 22
    lg = first{ILogger}(logs%elements)
    if (lg%log(1) /= 3) error stop 23
    call fill{IShape}(Square(3), 3, arr)
    if (lbound(arr, 1) /= 0 .or. size(arr) /= 3 .or. arr(2)%area() /= 9) error stop 24
    call arr(0)%scale(2)
    call swap_ends{IShape}(arr)
    if (arr(0)%area() /= 9 .or. arr(2)%area() /= 36) error stop 25
    call swap_ends(rects%elements)
    if (rects%elements(1)%area() /= 30 .or. rects%elements(3)%area() /= 90) error stop 26
    if (counted_twice{IShape}(arr) /= 4) error stop 27
    deallocate(arr)
    if (allocated(arr)) error stop 28

    ! Intrinsic assignment of a structure copies its vector's elements.
    s1%id = 1
    call s1%shapes%append(Square(2))
    call s1%shapes%append(Square(3))
    s2 = s1
    call s1%shapes%elements(1)%scale(10)
    if (s1%shapes%elements(1)%area() /= 400) error stop 29
    if (s2%id /= 1 .or. s2%shapes%length() /= 2) error stop 30
    if (s2%shapes%elements(1)%area() /= 4 .or. s2%shapes%elements(2)%area() /= 9) error stop 31

    call squares%clear()
    call rects%clear()
    call logs%clear()
    call s1%shapes%clear()
    call s2%shapes%clear()
    print *, "ok"
end program traits_trait_param_array_01
