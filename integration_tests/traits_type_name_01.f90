! The type_name intrinsic (DI extension E7): type_name{P}() is the name of the
! type or trait P with the letter case of its declaration, and
! type_name{P}(qualified=.true.) prefixes the scoping units that contain the
! declaration. It is a constant where P is known, including in named
! constants, and a generic parameter P is replaced when the generic is
! instantiated, for type parameters and trait parameters, forwarded or not.
! An instance of a generic derived type is named with its type arguments.
! An entity named type_name hides the intrinsic.
! GFortran does not accept this LFortran extension.
module Traits_Type_Name_01_Shapes
    implicit none
    private
    public :: IShape, SquareBox, plainType, box_name, qualified_length

    abstract interface :: IShape
        real function area(self)
            type(itself), intent(in), pass :: self
        end function area
    end interface IShape

    type, implements(IShape) :: SquareBox
        real :: side = 2
    contains
        procedure :: area => square_area
    end type SquareBox

    type :: plainType
        integer :: unused = 0
    end type plainType

    character(len=*), parameter :: box_name = type_name{SquareBox}()
    integer, parameter :: qualified_length = &
        len(type_name{IShape}(qualified=.true.))

contains

    real function square_area(self)
        class(SquareBox), intent(in) :: self
        square_area = self%side**2
    end function square_area

end module Traits_Type_Name_01_Shapes

module Traits_Type_Name_01_Generic
    use Traits_Type_Name_01_Shapes, only: IShape
    implicit none
    private
    public :: name_of, qualified_name_of, shape_name, forwarded_name, &
        trait_key, forwarded_trait_key, local_type_name, Holder

    type :: Holder{T}
        type(T) :: item
    end type Holder

contains

    ! An unconstrained type parameter.
    function name_of{T}(x) result(r)
        type(T), intent(in) :: x
        character(:), allocatable :: r
        r = type_name{T}()
    end function name_of

    function qualified_name_of{T}(x) result(r)
        type(T), intent(in) :: x
        character(:), allocatable :: r
        r = type_name{T}(qualified=.true.)
    end function qualified_name_of

    ! A constrained type parameter, in an expression.
    function shape_name{IShape :: T}(x) result(r)
        type(T), intent(in) :: x
        character(:), allocatable :: r
        r = "<" // type_name{T}() // ">"
    end function shape_name

    ! T passed on to another generic.
    function forwarded_name{T}(x) result(r)
        type(T), intent(in) :: x
        character(:), allocatable :: r
        r = name_of{T}(x) // "|" // qualified_name_of(x)
    end function forwarded_name

    ! A trait parameter, in an inferred declaration and a message.
    function trait_key{Trait :: P}() result(r)
        character(:), allocatable :: r
        key := type_name{P}(qualified=.true.)
        r = key // " (" // type_name{P}() // ")"
    end function trait_key

    function forwarded_trait_key{Trait :: P}() result(r)
        character(:), allocatable :: r
        r = trait_key{P}()
    end function forwarded_trait_key

    ! A derived type declared in a procedure.
    function local_type_name() result(r)
        character(:), allocatable :: r
        type :: LocalPoint
            integer :: x = 0
        end type LocalPoint
        r = type_name{LocalPoint}(qualified=.true.)
    end function local_type_name

end module Traits_Type_Name_01_Generic

module Traits_Type_Name_01_Hide
    implicit none
contains
    ! A user function named type_name.
    integer function type_name(n)
        integer, intent(in) :: n
        type_name = 2 * n
    end function type_name
end module Traits_Type_Name_01_Hide

program Traits_Type_Name_01
    use Traits_Type_Name_01_Shapes, only: IShape, SquareBox, Box => SquareBox, &
        plainType, box_name, qualified_length
    use Traits_Type_Name_01_Generic
    implicit none

    type :: ProgramPoint
        integer :: x = 0
    end type ProgramPoint

    type(SquareBox) :: s
    type(plainType) :: p
    type(Holder{SquareBox}) :: h
    character(len=*), parameter :: shape_trait = type_name{IShape}()

    ! Derived types and traits, unqualified and qualified.
    call check(type_name{SquareBox}(), "SquareBox", 1)
    call check(type_name{Box}(), "SquareBox", 2)
    call check(type_name{plainType}(), "plainType", 3)
    call check(type_name{IShape}(), "IShape", 4)
    call check(type_name{SquareBox}(qualified=.true.), &
        "Traits_Type_Name_01_Shapes::SquareBox", 5)
    call check(type_name{IShape}(qualified=.true.), &
        "Traits_Type_Name_01_Shapes::IShape", 6)
    call check(type_name{ProgramPoint}(qualified=.true.), &
        "Traits_Type_Name_01::ProgramPoint", 7)
    call check(local_type_name(), &
        "Traits_Type_Name_01_Generic::local_type_name::LocalPoint", 8)
    call check(type_name{type(SquareBox)}(.false.), "SquareBox", 9)

    ! Intrinsic types, with their kinds; qualified changes nothing.
    call check(type_name{integer}(), "integer(4)", 10)
    call check(type_name{real(8)}(), "real(8)", 11)
    call check(type_name{logical}(qualified=.true.), "logical(4)", 12)
    call check(type_name{complex(4)}(), "complex(4)", 13)
    call check(type_name{character(len=3)}(), "character(len=3)", 14)

    ! Constant expressions.
    call check(box_name, "SquareBox", 15)
    if (qualified_length /= len("Traits_Type_Name_01_Shapes::IShape")) error stop 16
    call check(shape_trait, "IShape", 17)

    ! Generic parameters, replaced in each instance.
    call check(name_of(s), "SquareBox", 18)
    call check(name_of(p), "plainType", 19)
    call check(name_of(1.5d0), "real(8)", 20)
    call check(name_of{integer}(3), "integer(4)", 21)
    call check(qualified_name_of(p), "Traits_Type_Name_01_Shapes::plainType", 22)
    call check(shape_name(s), "<SquareBox>", 23)
    call check(forwarded_name(s), &
        "SquareBox|Traits_Type_Name_01_Shapes::SquareBox", 24)
    call check(trait_key{IShape}(), &
        "Traits_Type_Name_01_Shapes::IShape (IShape)", 25)
    call check(forwarded_trait_key{IShape}(), &
        "Traits_Type_Name_01_Shapes::IShape (IShape)", 26)

    ! Instances of a generic derived type.
    call check(type_name{type(Holder{integer})}(), "Holder{integer(4)}", 27)
    call check(type_name{type(Holder{SquareBox})}(qualified=.true.), &
        "Traits_Type_Name_01_Generic::Holder{SquareBox}", 28)
    call check(name_of(h), "Holder{SquareBox}", 29)

    call hidden_variable()
    call hidden_function()
    print *, "PASSED"

contains

    subroutine check(actual, expected, code)
        character(*), intent(in) :: actual, expected
        integer, intent(in) :: code
        if (len(actual) /= len(expected) .or. actual /= expected) then
            print *, code, "'" // actual // "' /= '" // expected // "'"
            error stop code
        end if
    end subroutine check

    ! A variable named type_name hides the intrinsic.
    subroutine hidden_variable()
        integer :: type_name
        type_name = 3
        if (type_name /= 3) error stop 40
    end subroutine hidden_variable

    ! So does a function named type_name.
    subroutine hidden_function()
        use Traits_Type_Name_01_Hide, only: type_name
        if (type_name(5) /= 10) error stop 41
    end subroutine hidden_function

end program Traits_Type_Name_01
